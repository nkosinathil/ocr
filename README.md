# MXA OCR - Optical Character Recognition Web Application

**Version:** 1.0.0  
**Product Name:** MXA OCR  
**Public URL:** https://ocr.gismartanalytics.com  
**Status:** Active Development

---

## Overview

MXA OCR is a standalone web-based Optical Character Recognition (OCR) application designed to extract text from PDF documents and images. This is an independent, self-contained product with its own infrastructure, database, authentication, and processing pipeline.

### Key Features

- 📄 **Document Processing**: Extract text from PDFs, images (PNG, JPG, TIFF)
- 🔐 **Enterprise Authentication**: Keycloak SSO integration with role-based access control
- ⚡ **Asynchronous Processing**: Background job processing with Celery
- 📊 **Job Management**: Track processing status, view history, manage results
- 💾 **Secure Storage**: MinIO object storage for documents and results
- 📈 **Audit Trail**: Complete logging of all user actions
- 🌐 **Web-Based**: No desktop software required, accessible from any browser

---

## Architecture

This application uses a **multi-tier architecture**:

```
┌─────────────┐      ┌──────────────┐      ┌─────────────────┐
│  PHP Web    │ ───> │  PostgreSQL  │      │   Keycloak SSO  │
│  Frontend   │      │   Database   │      │  (Auth Server)  │
│ (Apache)    │ <─── └──────────────┘      └─────────────────┘
└──────┬──────┘
       │
       │ HTTP API
       ▼
┌─────────────────────────────────────────┐
│    Python Backend (FastAPI + Celery)    │
│  ┌──────────┐         ┌──────────────┐  │
│  │ FastAPI  │ ◄────── │    Redis     │  │
│  │  (API)   │         │ (Job Queue)  │  │
│  └──────────┘         └──────────────┘  │
│       │                                  │
│       │                                  │
│  ┌────▼──────────┐                      │
│  │ Celery Worker │                      │
│  │ (OCR Engine)  │                      │
│  └───────────────┘                      │
└──────────┬──────────────────────────────┘
           │
           ▼
    ┌──────────────┐
    │    MinIO     │
    │   Storage    │
    └──────────────┘
```

### Components

| Component | Technology | Purpose | Location |
|-----------|-----------|---------|----------|
| **Frontend** | PHP 8.1 + Apache | Web UI, user interaction | 192.168.1.66 |
| **API Backend** | Python FastAPI | REST API, job orchestration | 192.168.1.90:8100 |
| **Worker** | Python Celery | Background OCR processing | 192.168.1.90 |
| **Database** | PostgreSQL 14+ | Application data, job status | 192.168.1.66 |
| **Auth** | Keycloak OIDC | Single Sign-On, authorization | 192.168.1.59 |
| **Storage** | MinIO S3 | Document and result storage | 192.168.1.90 |
| **Queue** | Redis | Task queue, result cache | 192.168.1.90 |

---

## Product Configuration

### Dedicated Resources

This product has its own isolated resources:

- **Database**: `mxa_ocr` (user: `mxa_ocr_user`)
- **Keycloak Client**: `mxa-ocr-web`
- **MinIO Buckets**: `mxa-ocr-input`, `mxa-ocr-output`
- **FastAPI Port**: `8100`
- **Celery Queue**: `mxa_ocr`
- **PHP App Path**: `/var/www/mxa-ocr-app/current`
- **Python App Path**: `/opt/apps/mxa-ocr`
- **Apache VHost**: `ocr.gismartanalytics.com`

### Infrastructure

- **App Server** (192.168.1.66): Apache, PHP, PostgreSQL
- **SSO Server** (192.168.1.59): Keycloak
- **Python Server** (192.168.1.90): FastAPI, Celery, Redis, MinIO

---

## Quick Start

### Prerequisites

- PHP 8.1+
- Python 3.10+
- PostgreSQL 14+
- Apache 2.4+
- Redis 6+
- MinIO (or S3-compatible storage)
- Keycloak 20+ with configured realm

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/nkosinathil/ocr.git mxa-ocr
   cd mxa-ocr
   ```

2. **Set up the database**
   ```bash
   cd database
   psql -U postgres -f schema.sql
   ```

3. **Configure PHP application**
   ```bash
   cd php-app
   cp .env.example .env
   # Edit .env with your configuration
   composer install
   ```

4. **Configure Python backend**
   ```bash
   cd python-backend
   cp .env.example .env
   # Edit .env with your configuration
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```

5. **Deploy services**
   ```bash
   cd deploy
   # Follow deployment instructions in deploy/README.md
   ```

For detailed installation instructions, see [docs/deployment.md](docs/deployment.md).

---

## Directory Structure

```
mxa-ocr/
├── php-app/              # PHP web frontend
│   ├── public/           # Web root
│   ├── src/              # Application code
│   └── .env.example      # PHP configuration template
│
├── python-backend/       # Python processing backend
│   ├── app/              # FastAPI application
│   ├── requirements.txt  # Python dependencies
│   └── .env.example      # Python configuration template
│
├── database/             # Database schemas and migrations
│   ├── schema.sql        # Complete database schema
│   └── migrations/       # Migration scripts
│
├── deploy/               # Deployment configurations
│   ├── apache/           # Apache vhost config
│   ├── systemd/          # Service definitions
│   └── scripts/          # Deployment automation
│
└── docs/                 # Documentation
    ├── architecture.md   # System architecture
    ├── deployment.md     # Deployment guide
    ├── api.md           # API documentation
    └── ...              # Additional docs
```

---

## Documentation

Comprehensive documentation is available in the [`docs/`](docs/) directory:

- **[Architecture](docs/architecture.md)**: System design and component interaction
- **[Configuration](docs/configuration.md)**: Environment variables and settings
- **[Deployment](docs/deployment.md)**: Installation and deployment procedures
- **[Database](docs/database.md)**: Schema, migrations, and data model
- **[API](docs/api.md)**: REST API endpoints and usage
- **[Authentication](docs/authentication.md)**: SSO integration and security
- **[Maintenance](docs/maintenance.md)**: Operational procedures
- **[Troubleshooting](docs/troubleshooting.md)**: Common issues and solutions

---

## Development

### Running Locally

**PHP Frontend:**
```bash
cd php-app
php -S localhost:8080 -t public
```

**Python API:**
```bash
cd python-backend
source venv/bin/activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8100
```

**Celery Worker:**
```bash
cd python-backend
source venv/bin/activate
celery -A app.tasks.celery_app worker --loglevel=info -Q mxa_ocr
```

### Testing

**PHP Tests:**
```bash
cd php-app
composer test
```

**Python Tests:**
```bash
cd python-backend
pytest
```

---

## Security

- ✅ OIDC/OAuth2 authentication via Keycloak
- ✅ Role-based access control (RBAC)
- ✅ CSRF protection on all forms
- ✅ Secure session management
- ✅ SQL injection prevention (parameterized queries)
- ✅ XSS protection (input sanitization)
- ✅ File upload validation
- ✅ Audit logging for all actions
- ✅ Environment-based secrets (no hardcoded credentials)

---

## Support

For issues, questions, or contributions:

1. Check the [Troubleshooting Guide](docs/troubleshooting.md)
2. Review existing GitHub issues
3. Create a new issue with detailed information

---

## License

Proprietary - Internal Use Only

---

## Changelog

### Version 1.0.0 (2026-04-10)
- Initial release
- Basic OCR functionality
- Keycloak SSO integration
- Job queue processing
- MinIO storage integration

---

**Note**: This is a standalone product. It does not share code, configuration, or infrastructure with any other application. All resources are dedicated to this product only.
