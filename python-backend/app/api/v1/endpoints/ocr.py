import logging
import uuid
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, File, Form, HTTPException, UploadFile, status

from app.database import execute_query, execute_query_fetchall, execute_query_fetchone
from app.models.schemas import (
    JobCreateRequest,
    JobCreateResponse,
    JobResultResponse,
    JobStatusResponse,
    PageResult,
    UploadResponse,
)
from app.services.minio_service import MinIOService
from app.tasks.ocr_tasks import process_ocr_job
from app.utils.helpers import detect_upload_type, generate_stored_filename

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/jobs", response_model=JobCreateResponse, status_code=status.HTTP_201_CREATED)
async def create_ocr_job(request: JobCreateRequest):
    upload = execute_query_fetchone(
        "SELECT id, stored_filename, mime_type, user_id FROM uploads WHERE id = %s",
        (str(request.upload_id),),
    )
    if not upload:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Upload {request.upload_id} not found",
        )

    job_id = uuid.uuid4()
    now = datetime.now(timezone.utc)

    execute_query(
        """
        INSERT INTO ocr_jobs (id, upload_id, user_id, status, language, engine, priority, created_at, updated_at)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        """,
        (
            str(job_id),
            str(request.upload_id),
            upload.get("user_id"),
            "queued",
            request.language,
            request.engine,
            request.priority,
            now,
            now,
        ),
    )

    process_ocr_job.delay(str(job_id))
    logger.info("OCR job %s created and dispatched for upload %s", job_id, request.upload_id)

    return JobCreateResponse(
        job_id=job_id,
        status="queued",
        message="OCR job created and queued for processing",
    )


@router.get("/jobs", response_model=list[JobStatusResponse])
async def list_jobs(
    user_id: Optional[str] = None,
    skip: int = 0,
    limit: int = 20,
):
    if limit > 100:
        limit = 100

    if user_id:
        rows = execute_query_fetchall(
            """
            SELECT id AS job_id, status, progress_percent, pages_processed, pages_total,
                   started_at, completed_at, error_message, created_at, updated_at
            FROM ocr_jobs
            WHERE user_id = %s
            ORDER BY created_at DESC
            OFFSET %s LIMIT %s
            """,
            (user_id, skip, limit),
        )
    else:
        rows = execute_query_fetchall(
            """
            SELECT id AS job_id, status, progress_percent, pages_processed, pages_total,
                   started_at, completed_at, error_message, created_at, updated_at
            FROM ocr_jobs
            ORDER BY created_at DESC
            OFFSET %s LIMIT %s
            """,
            (skip, limit),
        )

    return [JobStatusResponse(**row) for row in rows]


@router.get("/jobs/{job_id}/status", response_model=JobStatusResponse)
async def get_job_status(job_id: uuid.UUID):
    row = execute_query_fetchone(
        """
        SELECT id AS job_id, status, progress_percent, pages_processed, pages_total,
               started_at, completed_at, error_message, created_at, updated_at
        FROM ocr_jobs
        WHERE id = %s
        """,
        (str(job_id),),
    )
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Job {job_id} not found",
        )
    return JobStatusResponse(**row)


@router.get("/jobs/{job_id}/result", response_model=JobResultResponse)
async def get_job_result(job_id: uuid.UUID):
    job = execute_query_fetchone(
        "SELECT id, status FROM ocr_jobs WHERE id = %s",
        (str(job_id),),
    )
    if not job:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Job {job_id} not found",
        )
    if job["status"] != "completed":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Job is not completed yet. Current status: {job['status']}",
        )

    results = execute_query_fetchall(
        """
        SELECT page_number, extracted_text, confidence_score, word_count
        FROM ocr_results
        WHERE job_id = %s
        ORDER BY page_number ASC
        """,
        (str(job_id),),
    )
    if not results:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No results found for job {job_id}",
        )

    pages = [
        PageResult(
            page_number=r["page_number"],
            text=r["extracted_text"],
            confidence_score=r["confidence_score"],
            word_count=r["word_count"],
        )
        for r in results
    ]

    full_text = "\n\n".join(p.text for p in pages)
    total_word_count = sum(p.word_count for p in pages)

    return JobResultResponse(
        job_id=job_id,
        pages=pages,
        total_word_count=total_word_count,
        full_text=full_text,
        format="text",
    )


@router.delete("/jobs/{job_id}", status_code=status.HTTP_200_OK)
async def cancel_job(job_id: uuid.UUID):
    job = execute_query_fetchone(
        "SELECT id, status FROM ocr_jobs WHERE id = %s",
        (str(job_id),),
    )
    if not job:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Job {job_id} not found",
        )
    if job["status"] in ("completed", "failed", "cancelled"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot cancel job with status: {job['status']}",
        )

    execute_query(
        """
        UPDATE ocr_jobs SET status = 'cancelled', updated_at = %s WHERE id = %s
        """,
        (datetime.now(timezone.utc), str(job_id)),
    )
    logger.info("Job %s cancelled", job_id)
    return {"job_id": str(job_id), "status": "cancelled", "message": "Job cancelled successfully"}


@router.post("/upload", response_model=UploadResponse, status_code=status.HTTP_201_CREATED)
async def upload_file(
    file: UploadFile = File(...),
    user_id: str = Form(...),
):
    allowed_types = {
        "application/pdf",
        "image/png",
        "image/jpeg",
        "image/tiff",
        "image/bmp",
        "image/gif",
        "image/webp",
    }
    if file.content_type not in allowed_types:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"Unsupported file type: {file.content_type}. Allowed: {', '.join(sorted(allowed_types))}",
        )

    file_data = await file.read()
    file_size = len(file_data)

    if file_size == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is empty",
        )

    max_size = 50 * 1024 * 1024  # 50 MB
    if file_size > max_size:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"File too large. Maximum size is {max_size // (1024 * 1024)} MB",
        )

    upload_id = uuid.uuid4()
    stored_filename = generate_stored_filename(file.filename or "unknown")
    upload_type = detect_upload_type(file.content_type)
    now = datetime.now(timezone.utc)

    minio_service = MinIOService()
    from app.config import get_settings

    settings = get_settings()
    minio_service.upload_file(
        bucket=settings.MINIO_BUCKET_UPLOADS,
        object_name=stored_filename,
        file_data=file_data,
        content_type=file.content_type,
    )

    execute_query(
        """
        INSERT INTO uploads (id, user_id, original_filename, stored_filename, mime_type,
                             file_size_bytes, upload_type, created_at)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """,
        (
            str(upload_id),
            user_id,
            file.filename,
            stored_filename,
            file.content_type,
            file_size,
            upload_type,
            now,
        ),
    )

    logger.info("File uploaded: %s -> %s (%d bytes)", file.filename, stored_filename, file_size)

    return UploadResponse(
        upload_id=upload_id,
        original_filename=file.filename or "unknown",
        mime_type=file.content_type,
        file_size_bytes=file_size,
        upload_type=upload_type,
        created_at=now,
    )
