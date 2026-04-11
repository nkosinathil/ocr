"""
MXA OCR - Configuration Module

Manages all environment-based configuration for the Python backend.
This is specific to the MXA OCR product only.
"""

import json
import os
from typing import Any, List, Optional
from pydantic import field_validator
from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""
    
    # Application
    app_name: str = "MXA OCR Backend"
    app_env: str = "production"
    app_debug: bool = False
    app_host: str = "0.0.0.0"
    app_port: int = 8100
    app_workers: int = 4
    
    # Database
    db_host: str = "192.168.1.66"
    db_port: int = 5432
    db_name: str = "mxa_ocr"
    db_user: str = "mxa_ocr_user"
    db_password: str
    db_pool_size: int = 20
    db_max_overflow: int = 10
    
    # Redis
    redis_host: str = "192.168.1.90"
    redis_port: int = 6379
    redis_db: int = 0
    redis_password: Optional[str] = None
    redis_result_backend_db: int = 1
    
    # Celery
    celery_broker_url: str = "redis://192.168.1.90:6379/0"
    celery_result_backend: str = "redis://192.168.1.90:6379/1"
    celery_task_serializer: str = "json"
    celery_result_serializer: str = "json"
    celery_accept_content: List[str] = ["json"]
    celery_timezone: str = "Africa/Johannesburg"
    celery_enable_utc: bool = True
    celery_task_track_started: bool = True
    celery_task_time_limit: int = 1800
    celery_task_soft_time_limit: int = 1500
    celery_worker_concurrency: int = 4
    celery_worker_prefetch_multiplier: int = 1
    celery_queue_name: str = "mxa_ocr"
    
    # MinIO
    minio_endpoint: str = "192.168.1.90:9000"
    minio_access_key: str
    minio_secret_key: str
    minio_bucket_input: str = "mxa-ocr-input"
    minio_bucket_output: str = "mxa-ocr-output"
    minio_secure: bool = False
    minio_region: str = "us-east-1"
    
    # OCR
    ocr_engine: str = "tesseract"
    ocr_default_language: str = "eng"
    ocr_languages: str = "eng,afr,ara,fra,deu,spa"
    ocr_dpi: int = 300
    ocr_timeout: int = 900
    tesseract_cmd: str = "/usr/bin/tesseract"
    
    # File Processing
    max_file_size_mb: int = 50
    allowed_extensions: str = "pdf,png,jpg,jpeg,tiff,tif"
    temp_dir: str = "/tmp/mxa-ocr"
    output_formats: str = "txt,pdf,json"
    
    # Logging
    log_level: str = "INFO"
    log_format: str = "json"
    log_file: str = "/var/log/mxa-ocr/backend.log"
    log_max_bytes: int = 10485760
    log_backup_count: int = 10
    
    # Security
    api_key: Optional[str] = None
    cors_origins: List[str] = ["https://ocr.gismartanalytics.com"]
    cors_allow_credentials: bool = True
    
    # Performance
    worker_timeout: int = 300
    request_timeout: int = 60
    connection_pool_size: int = 100
    
    class Config:
        env_file = ".env"
        case_sensitive = False

    @field_validator('celery_accept_content', 'cors_origins', mode='before')
    @classmethod
    def _parse_list_field(cls, v: Any) -> Any:
        """Accept both JSON array format and comma-separated plain strings."""
        if isinstance(v, str):
            try:
                parsed = json.loads(v)
                if isinstance(parsed, list):
                    return parsed
            except (json.JSONDecodeError, ValueError):
                pass
            return [item.strip() for item in v.split(',') if item.strip()]
        return v
        
    @property
    def database_url(self) -> str:
        """Get PostgreSQL database URL."""
        return f"postgresql://{self.db_user}:{self.db_password}@{self.db_host}:{self.db_port}/{self.db_name}"
    
    @property
    def redis_url(self) -> str:
        """Get Redis URL."""
        if self.redis_password:
            return f"redis://:{self.redis_password}@{self.redis_host}:{self.redis_port}/{self.redis_db}"
        return f"redis://{self.redis_host}:{self.redis_port}/{self.redis_db}"
    
    @property
    def max_file_size_bytes(self) -> int:
        """Get max file size in bytes."""
        return self.max_file_size_mb * 1024 * 1024
    
    @property
    def allowed_extensions_list(self) -> List[str]:
        """Get list of allowed file extensions."""
        return [ext.strip() for ext in self.allowed_extensions.split(",")]
    
    @property
    def output_formats_list(self) -> List[str]:
        """Get list of output formats."""
        return [fmt.strip() for fmt in self.output_formats.split(",")]
    
    @property
    def ocr_languages_list(self) -> List[str]:
        """Get list of supported OCR languages."""
        return [lang.strip() for lang in self.ocr_languages.split(",")]


@lru_cache()
def get_settings() -> Settings:
    """
    Get cached settings instance.
    Uses lru_cache to ensure single instance.
    """
    return Settings()


# Global settings instance
settings = get_settings()
