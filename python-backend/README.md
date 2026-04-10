# MXA OCR - Python Backend

This directory contains the Python backend for the MXA OCR application, providing the OCR processing engine via FastAPI and Celery.

## Overview

The Python backend provides:
- FastAPI REST API for job submission and status
- Celery workers for asynchronous OCR processing
- MinIO integration for file storage
- PostgreSQL integration for job tracking
- Redis-based task queue

## Requirements

- Python 3.10 or higher
- PostgreSQL 14+ (for job status)
- Redis 6+ (for task queue)
- MinIO (for file storage)
- Tesseract OCR engine
- Poppler (for PDF processing)

## Directory Structure

```
python-backend/
├── app/
│   ├── __init__.py
│   ├── main.py              # FastAPI application entry point
│   ├── config.py            # Configuration management
│   ├── api/                 # API route handlers
│   │   ├── health.py        # Health check endpoints
│   │   ├── jobs.py          # Job management endpoints
│   │   └── results.py       # Results retrieval endpoints
│   ├── services/            # Business logic services
│   │   ├── ocr_service.py   # OCR processing logic
│   │   ├── storage_service.py  # MinIO integration
│   │   └── job_service.py   # Job management logic
│   ├── tasks/               # Celery tasks
│   │   ├── celery_app.py    # Celery configuration
│   │   └── ocr_tasks.py     # OCR processing tasks
│   ├── models/              # Pydantic models
│   │   ├── job.py           # Job models
│   │   └── result.py        # Result models
│   └── core/                # Core OCR processors
│       ├── pdf_processor.py     # PDF processing
│       ├── image_processor.py   # Image processing
│       └── text_extractor.py    # Text extraction
├── tests/                   # Test suite
├── requirements.txt         # Python dependencies
├── .env.example             # Environment configuration template
└── README.md                # This file
```

## Installation

### 1. Create Virtual Environment

```bash
cd python-backend
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### 2. Install Dependencies

```bash
pip install -r requirements.txt
```

### 3. Install System Dependencies

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y tesseract-ocr tesseract-ocr-eng tesseract-ocr-afr \
    poppler-utils libtesseract-dev
```

**Additional Languages:**
```bash
# Install more OCR languages as needed
sudo apt-get install tesseract-ocr-ara tesseract-ocr-fra tesseract-ocr-deu
```

### 4. Configure Environment

```bash
cp .env.example .env
```

Edit `.env` and update critical values:

```env
# Database
DB_PASSWORD=<your-secure-password>

# MinIO
MINIO_ACCESS_KEY=<your-minio-access-key>
MINIO_SECRET_KEY=<your-minio-secret-key>

# Paths
TEMP_DIR=/opt/apps/mxa-ocr/temp
LOG_FILE=/var/log/mxa-ocr/backend.log
```

### 5. Create Required Directories

```bash
sudo mkdir -p /opt/apps/mxa-ocr/temp
sudo mkdir -p /var/log/mxa-ocr
sudo chown -R $USER:$USER /opt/apps/mxa-ocr /var/log/mxa-ocr
```

## Running the Application

### Development Mode

**FastAPI (API Server):**
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8100
```

**Celery Worker:**
```bash
celery -A app.tasks.celery_app worker --loglevel=info -Q mxa_ocr
```

### Production Mode

Use systemd services (see `../deploy/systemd/`):

```bash
sudo systemctl start mxa-ocr-api
sudo systemctl start mxa-ocr-worker
```

## API Endpoints

### Health Endpoints

- `GET /api/v1/health` - Basic health check
- `GET /api/v1/health/detailed` - Detailed health with system metrics
- `GET /api/v1/ready` - Readiness check

### Job Endpoints

- `POST /api/v1/jobs` - Submit new OCR job
- `GET /api/v1/jobs/{job_id}` - Get job status
- `GET /api/v1/jobs` - List jobs (with filters)
- `DELETE /api/v1/jobs/{job_id}` - Cancel job

### Result Endpoints

- `GET /api/v1/results/{job_id}` - Get OCR results

## Testing

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=app --cov-report=html

# Run specific test file
pytest tests/test_ocr_service.py
```

## Configuration

### Environment Variables

See `.env.example` for all available configuration options.

Key sections:
- **Application**: Host, port, workers
- **Database**: PostgreSQL connection
- **Redis**: Task queue connection
- **Celery**: Worker and task configuration
- **MinIO**: Object storage connection
- **OCR**: Tesseract configuration
- **File Processing**: Upload limits, temp directories
- **Logging**: Log levels and paths

### Celery Configuration

- **Queue Name**: `mxa_ocr` (dedicated to this product)
- **Concurrency**: 4 workers (configurable)
- **Task Timeout**: 30 minutes (1800 seconds)
- **Soft Timeout**: 25 minutes (warning before hard timeout)
- **Retry Policy**: 3 retries with exponential backoff

### MinIO Buckets

- **Input**: `mxa-ocr-input` (uploaded files)
- **Output**: `mxa-ocr-output` (processed results)

## Architecture

### Request Flow (API)

1. Client → FastAPI endpoint
2. Validate request data
3. Create job record in database
4. Submit Celery task to queue
5. Return job ID to client

### Processing Flow (Worker)

1. Celery worker picks task from queue
2. Update job status to "processing"
3. Download file from MinIO input bucket
4. Perform OCR extraction
5. Save results to MinIO output bucket
6. Update job status and save results to database
7. Clean up temporary files

## Monitoring

### Check API Status

```bash
curl http://localhost:8100/api/v1/health
```

### Check Celery Worker

```bash
celery -A app.tasks.celery_app inspect active
celery -A app.tasks.celery_app inspect stats
```

### View Logs

```bash
# API logs
tail -f /var/log/mxa-ocr/backend.log

# Celery logs
journalctl -u mxa-ocr-worker -f
```

## Troubleshooting

### "ModuleNotFoundError"

- Ensure virtual environment is activated
- Reinstall dependencies: `pip install -r requirements.txt`

### "Connection refused" (Database)

- Verify PostgreSQL is running
- Check database credentials in `.env`
- Test: `psql -h 192.168.1.66 -U mxa_ocr_user -d mxa_ocr`

### "Tesseract not found"

- Install Tesseract: `sudo apt-get install tesseract-ocr`
- Verify path in `.env`: `TESSERACT_CMD=/usr/bin/tesseract`

### MinIO Connection Errors

- Verify MinIO is accessible
- Check credentials in `.env`
- Test with MinIO client: `mc ls myminio/mxa-ocr-input`

## Performance Tuning

### Worker Concurrency

Adjust based on CPU cores:
```env
CELERY_WORKER_CONCURRENCY=8  # For 8-core system
```

### Task Timeout

For large files, increase timeout:
```env
CELERY_TASK_TIME_LIMIT=3600  # 1 hour
```

### Database Connection Pool

```env
DB_POOL_SIZE=30
DB_MAX_OVERFLOW=20
```

## Security

- ✅ No hardcoded secrets (all in .env)
- ✅ Input validation via Pydantic
- ✅ File type validation
- ✅ Size limits enforced
- ✅ Secure file handling (temp files cleaned up)
- ✅ Task isolation (dedicated queue)

## Related Documentation

- [Main README](../README.md) - Project overview
- [Architecture](../docs/architecture.md) - System architecture
- [API Documentation](../docs/api.md) - Complete API reference
- [Deployment](../docs/deployment.md) - Deployment procedures

## Support

For backend-specific issues, check logs and verify:
1. All services are running (FastAPI, Celery, Redis, MinIO, PostgreSQL)
2. Network connectivity between services
3. Correct environment configuration
4. Sufficient system resources (CPU, memory, disk)
