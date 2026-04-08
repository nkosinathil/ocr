from datetime import datetime
from typing import List, Optional
from uuid import UUID

from pydantic import BaseModel, Field


class JobCreateRequest(BaseModel):
    upload_id: UUID
    language: str = "eng"
    engine: str = "tesseract"
    priority: int = 0


class JobCreateResponse(BaseModel):
    job_id: UUID
    status: str
    message: str


class JobStatusResponse(BaseModel):
    job_id: UUID
    status: str
    progress_percent: float = 0.0
    pages_processed: int = 0
    pages_total: int = 0
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    error_message: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class PageResult(BaseModel):
    page_number: int
    text: str
    confidence_score: float
    word_count: int


class JobResultResponse(BaseModel):
    job_id: UUID
    pages: List[PageResult]
    total_word_count: int
    full_text: str
    format: str


class UploadResponse(BaseModel):
    upload_id: UUID
    original_filename: str
    mime_type: str
    file_size_bytes: int
    upload_type: str
    created_at: Optional[datetime] = None


class HealthResponse(BaseModel):
    status: str
    version: str
    uptime: float = Field(description="Uptime in seconds")
