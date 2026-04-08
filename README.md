# OCR Platform

A production-style OCR (Optical Character Recognition) platform with a PHP frontend and Python processing backend. The system follows strict separation of concerns with SSO-based authentication, background job processing, and enterprise-grade architecture.

## Architecture

```
┌─────────────────┐     ┌─────────────────────┐     ┌──────────────────────────────────┐
│   SSO Server    │     │  Application Server  │     │     Processing Server            │
│  192.168.1.59   │◄───►│   192.168.1.66       │◄───►│      192.168.1.90                │
│                 │     │                      │     │                                  │
│ - Auth          │     │ - PHP + Apache       │     │ - FastAPI (port 8000)            │
│ - Token Issue   │     │ - PostgreSQL         │     │ - Celery Workers                 │
│ - Role Mgmt     │     │ - Dashboard UI       │     │ - Redis (queue/state)            │
│                 │     │ - Upload Handling     │     │ - MinIO (file storage)           │
│                 │     │ - Job Orchestration   │     │ - Tesseract OCR Engine           │
└─────────────────┘     └─────────────────────┘     └──────────────────────────────────┘
```

### Communication Flow

1. User accesses PHP app at `http://192.168.1.66`
2. PHP redirects to SSO at `http://192.168.1.59` for authentication
3. After login, user uploads files through PHP frontend
4. PHP sends files to Python API at `http://192.168.1.90:8000`
5. Python stores files in MinIO and creates Celery tasks
6. Celery workers process OCR in the background
7. PHP polls Python API for job status updates
8. Results are displayed through the PHP frontend

## Project Structure

```
├── database/
│   └── schema.sql              # PostgreSQL schema (tables, indexes, triggers)
├── php-app/                    # PHP Frontend Application
│   ├── config/
│   │   ├── app.php             # Application configuration
│   │   └── database.php        # Database connection singleton
│   ├── public/
│   │   ├── index.php           # Front controller / router
│   │   ├── .htaccess           # Apache rewrite rules
│   │   └── assets/
│   │       ├── css/app.css     # Enterprise-grade stylesheet
│   │       └── js/app.js       # Client-side JavaScript
│   ├── src/
│   │   ├── Controllers/        # AuthController, DashboardController, etc.
│   │   ├── Services/           # SsoService, ApiService, JobService, UploadService
│   │   ├── Models/             # User, Job (PostgreSQL queries)
│   │   └── Middleware/         # AuthMiddleware
│   ├── views/                  # PHP view templates
│   │   ├── layouts/main.php    # Master layout with sidebar navigation
│   │   ├── auth/               # Login page
│   │   ├── dashboard/          # Dashboard with stats
│   │   ├── upload/             # File upload with drag & drop
│   │   ├── jobs/               # Job listing and detail views
│   │   └── results/            # OCR result display
│   ├── apache/                 # Apache virtual host config
│   ├── .env.example            # Environment template
│   ├── composer.json           # PSR-4 autoload config
│   └── Dockerfile
├── python-backend/             # Python Processing Backend
│   ├── app/
│   │   ├── main.py             # FastAPI app with CORS, lifespan, routers
│   │   ├── config.py           # Pydantic Settings
│   │   ├── database.py         # PostgreSQL connection helpers
│   │   ├── api/v1/endpoints/
│   │   │   ├── ocr.py          # OCR endpoints (jobs, upload, status, results)
│   │   │   └── health.py       # Health check / info endpoints
│   │   ├── models/
│   │   │   └── schemas.py      # Pydantic request/response models
│   │   ├── services/
│   │   │   ├── minio_service.py    # MinIO file operations
│   │   │   └── ocr_service.py      # Tesseract OCR processing
│   │   ├── tasks/
│   │   │   ├── celery_app.py       # Celery configuration
│   │   │   └── ocr_tasks.py        # OCR background task
│   │   └── utils/
│   │       ├── auth.py             # Token verification
│   │       └── helpers.py          # Utility functions
│   ├── run.py                  # Uvicorn entry point
│   ├── requirements.txt
│   ├── .env.example
│   └── Dockerfile
└── docker-compose.yml          # Development docker-compose
```

## Technology Stack

| Component     | Technology                    | Server          |
|---------------|-------------------------------|-----------------|
| Frontend      | PHP 8.2 + Apache              | 192.168.1.66    |
| Database      | PostgreSQL 16                 | 192.168.1.66    |
| Backend API   | Python 3.12 + FastAPI         | 192.168.1.90    |
| Task Queue    | Celery + Redis                | 192.168.1.90    |
| File Storage  | MinIO                         | 192.168.1.90    |
| OCR Engine    | Tesseract                     | 192.168.1.90    |
| Auth          | SSO (OIDC/OAuth2 style)       | 192.168.1.59    |
| Font          | Roboto                        | Google Fonts    |

## Database Schema

Five core tables managed via PostgreSQL on `192.168.1.66`:

| Table            | Purpose                                        |
|------------------|------------------------------------------------|
| `users_local`    | Local user profiles synced from SSO            |
| `uploads`        | File upload metadata and MinIO references      |
| `ocr_jobs`       | OCR processing jobs with status tracking       |
| `ocr_results`    | Extracted text, confidence scores per page     |
| `job_logs`       | Audit trail for job lifecycle events           |

## API Endpoints (Python Backend)

| Method   | Endpoint                              | Description                |
|----------|---------------------------------------|----------------------------|
| `POST`   | `/api/v1/ocr/upload`                  | Upload file for OCR        |
| `POST`   | `/api/v1/ocr/jobs`                    | Create OCR processing job  |
| `GET`    | `/api/v1/ocr/jobs`                    | List jobs (with filters)   |
| `GET`    | `/api/v1/ocr/jobs/{id}/status`        | Get job status             |
| `GET`    | `/api/v1/ocr/jobs/{id}/result`        | Get OCR results            |
| `DELETE` | `/api/v1/ocr/jobs/{id}`               | Cancel a job               |
| `GET`    | `/health`                             | Health check               |
| `GET`    | `/info`                               | Application info           |

## Setup Instructions

### Prerequisites

- PHP 8.1+ with extensions: `pdo_pgsql`, `curl`, `mbstring`
- Apache 2.4+ with `mod_rewrite`
- Python 3.10+
- PostgreSQL 14+
- Redis 6+
- MinIO
- Tesseract OCR with language packs
- Composer (PHP dependency manager)

### Option A: Direct Server Deployment

#### 1. Database Setup (192.168.1.66)

```bash
# Create database and user
sudo -u postgres psql
CREATE DATABASE ocr_platform;
CREATE USER ocr_app WITH PASSWORD 'ocr_secure_password_2024';
GRANT ALL PRIVILEGES ON DATABASE ocr_platform TO ocr_app;
\c ocr_platform
GRANT ALL ON SCHEMA public TO ocr_app;
\q

# Apply schema
sudo -u postgres psql -d ocr_platform -f /path/to/database/schema.sql
```

#### 2. PHP Application (192.168.1.66)

```bash
# Clone and configure
cd /var/www
git clone <repo-url> ocr-platform
cd ocr-platform/php-app

# Install dependencies
composer install

# Configure environment
cp .env.example .env
# Edit .env with your credentials

# Apache config
sudo cp apache/ocr-platform.conf /etc/apache2/sites-available/
sudo a2ensite ocr-platform
sudo a2enmod rewrite headers
sudo systemctl restart apache2
```

#### 3. Python Backend (192.168.1.90)

```bash
cd /opt/ocr-backend
git clone <repo-url> .
cd python-backend

# Create virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Install Tesseract
sudo apt-get install -y tesseract-ocr tesseract-ocr-eng poppler-utils

# Configure environment
cp .env.example .env
# Edit .env with your credentials

# Start FastAPI
python run.py

# Start Celery worker (separate terminal)
celery -A app.tasks.celery_app:celery_app worker -l info -Q ocr,default -c 2
```

#### 4. Redis & MinIO (192.168.1.90)

```bash
# Redis
sudo apt-get install redis-server
sudo systemctl enable redis-server

# MinIO
wget https://dl.min.io/server/minio/release/linux-amd64/minio
chmod +x minio
./minio server /data --console-address ":9001"
```

### Option B: Docker Compose (Development)

```bash
# Start all services
docker compose up -d

# Access:
# PHP App:    http://localhost
# Python API: http://localhost:8000
# MinIO UI:   http://localhost:9001
```

### 5. SSO Server Configuration (192.168.1.59)

Register the OCR Platform as an OAuth2/OIDC client on your SSO server:

| Setting              | Value                                    |
|----------------------|------------------------------------------|
| Client ID            | `ocr-platform`                           |
| Redirect URI         | `http://192.168.1.66/auth/callback`      |
| Post-Logout URI      | `http://192.168.1.66/auth/logout`        |
| Scopes               | `openid profile email`                   |
| Grant Type           | Authorization Code                       |

## Supported File Types

| Format | Extensions           | MIME Type          |
|--------|----------------------|--------------------|
| PDF    | `.pdf`               | `application/pdf`  |
| JPEG   | `.jpg`, `.jpeg`      | `image/jpeg`       |
| PNG    | `.png`               | `image/png`        |
| TIFF   | `.tiff`, `.tif`      | `image/tiff`       |
| BMP    | `.bmp`               | `image/bmp`        |
| WebP   | `.webp`              | `image/webp`       |

## OCR Processing Pipeline

1. File fetched from MinIO storage
2. File type detection (PDF vs image)
3. Image preprocessing (grayscale, threshold, sharpen)
4. Tesseract OCR extraction with confidence scoring
5. Per-page result aggregation (for multi-page PDFs)
6. Results stored in PostgreSQL
7. Job status updated to `completed`
8. All steps logged to `job_logs` audit trail

## UI Pages

| Page             | Route              | Description                        |
|------------------|--------------------|------------------------------------|
| Login            | `/auth/login`      | SSO redirect                       |
| Dashboard        | `/`                | Stats overview + recent jobs       |
| Upload           | `/upload`          | Drag & drop file upload            |
| Jobs List        | `/jobs`            | Paginated job listing              |
| Job Detail       | `/jobs/{id}`       | Status, progress, timeline         |
| Results          | `/results/{id}`    | Extracted text with page tabs      |
| Download         | `/results/{id}/download` | Download results as TXT     |

## Production Considerations

- Enable HTTPS/SSL on all servers
- Replace IP addresses with domain names
- Set `APP_DEBUG=false` and `DEBUG=false`
- Rotate `APP_SECRET` and all passwords
- Configure proper MinIO access policies
- Set up systemd services for FastAPI and Celery
- Enable PostgreSQL connection pooling (PgBouncer)
- Configure log rotation and monitoring
- Add rate limiting to API endpoints
- Set up backup procedures for PostgreSQL and MinIO

## License

Proprietary. Internal use only.
