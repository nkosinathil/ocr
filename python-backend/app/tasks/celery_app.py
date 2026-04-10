"""
Celery Application Configuration

Configures Celery for asynchronous task processing.
This is specific to the MXA OCR product only.
"""

from celery import Celery
from app.config import settings

# Create Celery app
celery_app = Celery(
    "mxa_ocr",
    broker=settings.celery_broker_url,
    backend=settings.celery_result_backend,
)

# Configure Celery
celery_app.conf.update(
    task_serializer=settings.celery_task_serializer,
    result_serializer=settings.celery_result_serializer,
    accept_content=settings.celery_accept_content,
    timezone=settings.celery_timezone,
    enable_utc=settings.celery_enable_utc,
    task_track_started=settings.celery_task_track_started,
    task_time_limit=settings.celery_task_time_limit,
    task_soft_time_limit=settings.celery_task_soft_time_limit,
    worker_prefetch_multiplier=settings.celery_worker_prefetch_multiplier,
    worker_max_tasks_per_child=1000,
    task_acks_late=True,
    task_reject_on_worker_lost=True,
    task_default_queue=settings.celery_queue_name,
    task_default_exchange=settings.celery_queue_name,
    task_default_routing_key=settings.celery_queue_name,
)

# Task routes - all tasks go to the mxa_ocr queue
celery_app.conf.task_routes = {
    'app.tasks.ocr_tasks.*': {'queue': settings.celery_queue_name},
}

# Import tasks to register them
from app.tasks import ocr_tasks  # noqa: E402, F401
