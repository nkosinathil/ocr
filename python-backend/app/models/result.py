"""
Result Models

Pydantic models for OCR result data.
"""

from pydantic import BaseModel, Field
from typing import Optional, Dict, List, Any
from datetime import datetime


class ResultResponse(BaseModel):
    """OCR result response."""
    job_id: str
    extracted_text: Optional[str] = None
    page_count: Optional[int] = None
    confidence_score: Optional[float] = Field(None, ge=0.0, le=100.0)
    language_detected: Optional[str] = None
    processing_time_ms: Optional[int] = None
    output_formats: List[Dict[str, str]] = Field(default_factory=list)
    metadata: Dict[str, Any] = Field(default_factory=dict)
    created_at: datetime
    
    class Config:
        json_schema_extra = {
            "example": {
                "job_id": "123e4567-e89b-12d3-a456-426614174000",
                "extracted_text": "This is the extracted text from the document...",
                "page_count": 5,
                "confidence_score": 95.8,
                "language_detected": "eng",
                "processing_time_ms": 15000,
                "output_formats": [
                    {"format": "txt", "path": "output/result.txt"},
                    {"format": "pdf", "path": "output/result.pdf"},
                    {"format": "json", "path": "output/result.json"}
                ],
                "metadata": {
                    "tesseract_version": "4.1.1",
                    "dpi": 300
                },
                "created_at": "2024-01-15T10:30:00Z"
            }
        }
