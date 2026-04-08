import logging
import uuid
from datetime import datetime, timezone

from app.database import execute_query, execute_query_fetchone
from app.services.minio_service import MinIOService
from app.services.ocr_service import process_image, process_pdf
from app.tasks.celery_app import celery_app
from app.config import get_settings
from app.utils.helpers import detect_upload_type

logger = logging.getLogger(__name__)


def _log_job_event(job_id: str, level: str, message: str) -> None:
    execute_query(
        """
        INSERT INTO job_logs (id, job_id, level, message, created_at)
        VALUES (%s, %s, %s, %s, %s)
        """,
        (str(uuid.uuid4()), job_id, level, message, datetime.now(timezone.utc)),
    )


def _update_job_status(
    job_id: str,
    status: str,
    **kwargs,
) -> None:
    set_clauses = ["status = %s", "updated_at = %s"]
    params = [status, datetime.now(timezone.utc)]

    field_map = {
        "progress_percent": "progress_percent",
        "pages_processed": "pages_processed",
        "pages_total": "pages_total",
        "started_at": "started_at",
        "completed_at": "completed_at",
        "error_message": "error_message",
    }

    for kwarg_key, column_name in field_map.items():
        if kwarg_key in kwargs:
            set_clauses.append(f"{column_name} = %s")
            params.append(kwargs[kwarg_key])

    params.append(job_id)
    query = f"UPDATE ocr_jobs SET {', '.join(set_clauses)} WHERE id = %s"
    execute_query(query, tuple(params))


@celery_app.task(bind=True, name="app.tasks.ocr_tasks.process_ocr_job", max_retries=3)
def process_ocr_job(self, job_id: str) -> dict:
    logger.info("Starting OCR processing for job %s", job_id)
    _log_job_event(job_id, "INFO", "OCR processing started")

    try:
        now = datetime.now(timezone.utc)
        _update_job_status(job_id, "processing", started_at=now, progress_percent=0.0)

        upload_info = execute_query_fetchone(
            """
            SELECT u.stored_filename, u.mime_type, u.original_filename
            FROM uploads u
            JOIN ocr_jobs j ON j.upload_id = u.id::text
            WHERE j.id = %s
            """,
            (job_id,),
        )
        if not upload_info:
            raise ValueError(f"Upload not found for job {job_id}")

        _log_job_event(job_id, "INFO", f"Processing file: {upload_info['original_filename']}")

        settings = get_settings()
        minio_service = MinIOService()
        file_data = minio_service.download_file(
            bucket=settings.MINIO_BUCKET_UPLOADS,
            object_name=upload_info["stored_filename"],
        )

        _log_job_event(job_id, "INFO", f"Downloaded file ({len(file_data)} bytes)")

        upload_type = detect_upload_type(upload_info["mime_type"])

        job_row = execute_query_fetchone(
            "SELECT language FROM ocr_jobs WHERE id = %s",
            (job_id,),
        )
        language = job_row["language"] if job_row else "eng"

        if upload_type == "pdf":
            _log_job_event(job_id, "INFO", "Processing as PDF")
            page_results = process_pdf(file_data, language=language)
            total_pages = len(page_results)
            _update_job_status(job_id, "processing", pages_total=total_pages)

            for i, page in enumerate(page_results, start=1):
                result_id = str(uuid.uuid4())
                execute_query(
                    """
                    INSERT INTO ocr_results (id, job_id, page_number, extracted_text,
                                             confidence_score, word_count, created_at)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    """,
                    (
                        result_id,
                        job_id,
                        page["page_number"],
                        page["text"],
                        page["confidence"],
                        page["word_count"],
                        datetime.now(timezone.utc),
                    ),
                )
                progress = (i / total_pages) * 100.0
                _update_job_status(
                    job_id,
                    "processing",
                    pages_processed=i,
                    progress_percent=round(progress, 1),
                )
        else:
            _log_job_event(job_id, "INFO", "Processing as image")
            _update_job_status(job_id, "processing", pages_total=1)

            result = process_image(file_data, language=language)
            result_id = str(uuid.uuid4())
            execute_query(
                """
                INSERT INTO ocr_results (id, job_id, page_number, extracted_text,
                                         confidence_score, word_count, created_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    result_id,
                    job_id,
                    1,
                    result["text"],
                    result["confidence"],
                    result["word_count"],
                    datetime.now(timezone.utc),
                ),
            )
            _update_job_status(job_id, "processing", pages_processed=1, progress_percent=100.0)

        _update_job_status(
            job_id,
            "completed",
            completed_at=datetime.now(timezone.utc),
            progress_percent=100.0,
        )
        _log_job_event(job_id, "INFO", "OCR processing completed successfully")
        logger.info("OCR job %s completed successfully", job_id)

        return {"job_id": job_id, "status": "completed"}

    except Exception as exc:
        error_msg = str(exc)
        logger.exception("OCR job %s failed: %s", job_id, error_msg)
        _log_job_event(job_id, "ERROR", f"Processing failed: {error_msg}")

        try:
            _update_job_status(job_id, "failed", error_message=error_msg[:2000])
        except Exception:
            logger.exception("Failed to update job status to failed for %s", job_id)

        raise self.retry(exc=exc, countdown=60) if self.request.retries < self.max_retries else exc
