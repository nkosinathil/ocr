from functools import lru_cache
from typing import List

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    APP_NAME: str = "OCR Processing Engine"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False
    HOST: str = "0.0.0.0"
    PORT: int = 8000

    DATABASE_HOST: str = "192.168.1.66"
    DATABASE_PORT: int = 5432
    DATABASE_NAME: str = "ocr_platform"
    DATABASE_USER: str = "ocr_app"
    DATABASE_PASSWORD: str = "ocr_secure_password_2024"

    REDIS_HOST: str = "127.0.0.1"
    REDIS_PORT: int = 6379
    REDIS_DB: int = 0

    MINIO_ENDPOINT: str = "127.0.0.1:9000"
    MINIO_ACCESS_KEY: str = "minioadmin"
    MINIO_SECRET_KEY: str = "minioadmin"
    MINIO_BUCKET_UPLOADS: str = "ocr-uploads"
    MINIO_BUCKET_RESULTS: str = "ocr-results"
    MINIO_USE_SSL: bool = False

    CELERY_BROKER_URL: str = "redis://127.0.0.1:6379/0"
    CELERY_RESULT_BACKEND: str = "redis://127.0.0.1:6379/1"

    SSO_SERVER_URL: str = "http://192.168.1.59"
    SSO_TOKEN_VERIFY_URL: str = "http://192.168.1.59/api/token/verify"

    CORS_ORIGINS: str = "http://192.168.1.66,http://192.168.1.66:80"
    TESSERACT_CMD: str = "/usr/bin/tesseract"

    @property
    def database_url(self) -> str:
        return (
            f"postgresql://{self.DATABASE_USER}:{self.DATABASE_PASSWORD}"
            f"@{self.DATABASE_HOST}:{self.DATABASE_PORT}/{self.DATABASE_NAME}"
        )

    @property
    def redis_url(self) -> str:
        return f"redis://{self.REDIS_HOST}:{self.REDIS_PORT}/{self.REDIS_DB}"

    @property
    def cors_origins_list(self) -> List[str]:
        return [origin.strip() for origin in self.CORS_ORIGINS.split(",") if origin.strip()]

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


@lru_cache()
def get_settings() -> Settings:
    return Settings()
