"""
Results API

Handles OCR result retrieval and export.
"""

from fastapi import APIRouter, HTTPException, status
from uuid import UUID
import logging

from app.models.result import ResultResponse

router = APIRouter()
logger = logging.getLogger(__name__)


@router.get("/results/{job_id}", response_model=ResultResponse)
async def get_job_results(job_id: UUID):
    """
    Get OCR results for a completed job.
    """
    try:
        # TODO: Query database for results
        # For now, return placeholder
        
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Results not found for job {job_id}"
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get results: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get results: {str(e)}"
        )
