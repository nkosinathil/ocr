import time

from fastapi import APIRouter

from app.config import get_settings
from app.models.schemas import HealthResponse

router = APIRouter()


@router.get("/health", response_model=HealthResponse)
async def health_check():
    settings = get_settings()
    from app.main import startup_time

    uptime = time.time() - startup_time if startup_time > 0 else 0.0
    return HealthResponse(
        status="healthy",
        version=settings.APP_VERSION,
        uptime=uptime,
    )


@router.get("/info")
async def app_info():
    settings = get_settings()
    return {
        "name": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "debug": settings.DEBUG,
    }
