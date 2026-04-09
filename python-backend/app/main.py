import logging
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.endpoints.health import router as health_router
from app.api.v1.endpoints.ocr import router as ocr_router
from app.config import get_settings
from app.services.minio_service import MinIOService

logger = logging.getLogger(__name__)

startup_time: float = 0.0


@asynccontextmanager
async def lifespan(app: FastAPI):
    global startup_time
    startup_time = time.time()

    settings = get_settings()
    logging.basicConfig(
        level=logging.DEBUG if settings.DEBUG else logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    )

    logger.info("Starting %s v%s", settings.APP_NAME, settings.APP_VERSION)

    try:
        minio_service = MinIOService()
        minio_service.ensure_buckets()
        logger.info("MinIO buckets verified")
    except Exception:
        logger.exception("Failed to initialize MinIO buckets")

    yield

    logger.info("Shutting down %s", settings.APP_NAME)


def create_app() -> FastAPI:
    settings = get_settings()

    app = FastAPI(
        title=settings.APP_NAME,
        version=settings.APP_VERSION,
        lifespan=lifespan,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins_list,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(ocr_router, prefix="/api/v1/ocr", tags=["OCR"])
    app.include_router(health_router, tags=["Health"])

    return app


app = create_app()
