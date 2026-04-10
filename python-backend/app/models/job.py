"""
Job Models

Pydantic models for job data validation and serialization.
"""

from pydantic import BaseModel, Field
from typing import Optional, Dict, Any
from enum import Enum
from uuid import UUID
from datetime import datetime


class JobStatus(str, Enum):
    """Job status enumeration."""
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


class JobCreate(BaseModel):
    """Job creation request."""
    job_id: str = Field(..., description="Unique job ID (UUID)")
    user_id: str = Field(..., description="User ID who submitted the job")
    original_filename: str = Field(..., description="Original filename")
    file_size: int = Field(..., description="File size in bytes", gt=0)
    file_type: str = Field(..., description="MIME type")
    minio_input_path: str = Field(..., description="MinIO path to input file")
    priority: int = Field(default=5, description="Job priority (1-9)", ge=1, le=9)
    metadata: Dict[str, Any] = Field(default_factory=dict, description="Additional metadata")
    
    class Config:
        json_schema_extra = {
            "example": {
                "job_id": "123e4567-e89b-12d3-a456-426614174000",
                "user_id": "user-123",
                "original_filename": "document.pdf",
                "file_size": 1024000,
                "file_type": "application/pdf",
                "minio_input_path": "2024/01/15/job-id/document.pdf",
                "priority": 5,
                "metadata": {
                    "language": "eng",
                    "dpi": 300
                }
            }
        }


class JobResponse(BaseModel):
    """Job response."""
    job_id: str
    status: JobStatus
    message: Optional[str] = None
    task_id: Optional[str] = None
    error: Optional[str] = None
    
    class Config:
        json_schema_extra = {
            "example": {
                "job_id": "123e4567-e89b-12d3-a456-426614174000",
                "status": "pending",
                "message": "Job submitted successfully",
                "task_id": "celery-task-id-123"
            }
        }


class JobDetail(BaseModel):
    """Detailed job information."""
    job_id: str
    user_id: str
    status: JobStatus
    priority: int
    original_filename: str
    file_size: int
    file_type: str
    minio_input_path: str
    minio_output_path: Optional[str] = None
    submitted_at: datetime
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    error_message: Optional[str] = None
    retry_count: int = 0
    metadata: Dict[str, Any] = Field(default_factory=dict)
