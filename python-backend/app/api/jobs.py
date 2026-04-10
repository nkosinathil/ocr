"""
Jobs API

Handles OCR job submission, status, and management.
"""

from fastapi import APIRouter, HTTPException, status
from typing import List, Optional
from uuid import UUID
import logging

from app.models.job import JobCreate, JobResponse, JobStatus
from app.tasks.ocr_tasks import process_ocr_task

router = APIRouter()
logger = logging.getLogger(__name__)


@router.post("/jobs", response_model=JobResponse, status_code=status.HTTP_201_CREATED)
async def create_job(job: JobCreate):
    """
    Submit a new OCR processing job.
    
    The job will be queued for asynchronous processing.
    """
    try:
        # Validate job data
        if not job.minio_input_path:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="MinIO input path is required"
            )
        
        # Submit task to Celery
        task = process_ocr_task.apply_async(
            args=[job.dict()],
            queue='mxa_ocr',
            priority=job.priority
        )
        
        logger.info(f"Job {job.job_id} submitted to queue, task_id: {task.id}")
        
        return JobResponse(
            job_id=job.job_id,
            status=JobStatus.PENDING,
            message="Job submitted successfully",
            task_id=task.id
        )
        
    except Exception as e:
        logger.error(f"Failed to create job: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create job: {str(e)}"
        )


@router.get("/jobs/{job_id}", response_model=JobResponse)
async def get_job_status(job_id: UUID):
    """
    Get the status of a specific job.
    """
    try:
        # TODO: Query database for job status
        # For now, return a placeholder
        
        return JobResponse(
            job_id=str(job_id),
            status=JobStatus.PENDING,
            message="Job status retrieved"
        )
        
    except Exception as e:
        logger.error(f"Failed to get job status: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get job status: {str(e)}"
        )


@router.get("/jobs")
async def list_jobs(
    user_id: Optional[UUID] = None,
    status: Optional[JobStatus] = None,
    limit: int = 50,
    offset: int = 0
):
    """
    List jobs with optional filtering.
    """
    try:
        # TODO: Query database for jobs
        # For now, return empty list
        
        return {
            "jobs": [],
            "total": 0,
            "limit": limit,
            "offset": offset
        }
        
    except Exception as e:
        logger.error(f"Failed to list jobs: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to list jobs: {str(e)}"
        )


@router.delete("/jobs/{job_id}", status_code=status.HTTP_204_NO_CONTENT)
async def cancel_job(job_id: UUID):
    """
    Cancel a pending or processing job.
    """
    try:
        # TODO: Implement job cancellation
        # - Update job status in database
        # - Revoke Celery task if still pending
        
        logger.info(f"Job {job_id} cancelled")
        return None
        
    except Exception as e:
        logger.error(f"Failed to cancel job: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to cancel job: {str(e)}"
        )
