"""
Health Check API

Provides health and readiness endpoints.
"""

from fastapi import APIRouter
from datetime import datetime
import psutil
import platform

from app.config import settings

router = APIRouter()


@router.get("/health")
async def health_check():
    """
    Health check endpoint.
    Returns basic application health status.
    """
    return {
        "status": "healthy",
        "application": settings.app_name,
        "version": "1.0.0",
        "environment": settings.app_env,
        "timestamp": datetime.utcnow().isoformat(),
    }


@router.get("/health/detailed")
async def detailed_health_check():
    """
    Detailed health check with system metrics.
    """
    cpu_percent = psutil.cpu_percent(interval=1)
    memory = psutil.virtual_memory()
    disk = psutil.disk_usage('/')
    
    return {
        "status": "healthy",
        "application": settings.app_name,
        "version": "1.0.0",
        "environment": settings.app_env,
        "timestamp": datetime.utcnow().isoformat(),
        "system": {
            "platform": platform.system(),
            "python_version": platform.python_version(),
            "cpu_percent": cpu_percent,
            "memory": {
                "total_gb": round(memory.total / (1024**3), 2),
                "available_gb": round(memory.available / (1024**3), 2),
                "percent_used": memory.percent,
            },
            "disk": {
                "total_gb": round(disk.total / (1024**3), 2),
                "free_gb": round(disk.free / (1024**3), 2),
                "percent_used": disk.percent,
            },
        },
        "configuration": {
            "queue_name": settings.celery_queue_name,
            "worker_concurrency": settings.celery_worker_concurrency,
            "max_file_size_mb": settings.max_file_size_mb,
        }
    }


@router.get("/ready")
async def readiness_check():
    """
    Readiness check endpoint.
    Checks if the service is ready to accept requests.
    """
    # TODO: Add database connectivity check
    # TODO: Add Redis connectivity check
    # TODO: Add MinIO connectivity check
    
    return {
        "ready": True,
        "timestamp": datetime.utcnow().isoformat(),
    }
