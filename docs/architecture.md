# MXA OCR - System Architecture

## Overview

MXA OCR is a standalone web-based optical character recognition application built as a multi-tier distributed system. This document describes the system architecture, component interactions, and design decisions.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              Internet / Users                            │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │ HTTPS
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      App Server (192.168.1.66)                          │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │                    Apache + mod_php                             │   │
│  │  - SSL Termination                                              │   │
│  │  - Reverse Proxy                                                │   │
│  │  - Static File Serving                                          │   │
│  └──────────────────────────┬─────────────────────────────────────┘   │
│                             │                                           │
│  ┌──────────────────────────▼──────────────────────────────────────┐   │
│  │            PHP Web Frontend (MVC)                               │   │
│  │  - Controllers (routing, request handling)                      │   │
│  │  - Services (business logic)                                    │   │
│  │  - Repositories (data access)                                   │   │
│  │  - Views (templates)                                            │   │
│  │  - Session Management                                           │   │
│  │  - Python API Client                                            │   │
│  └──────────┬─────────────────────┬───────────────────────────────┘   │
│             │                     │                                     │
│             │                     ▼                                     │
│             │          ┌─────────────────┐                             │
│             │          │   PostgreSQL    │                             │
│             │          │  (mxa_ocr DB)   │                             │
│             │          └─────────────────┘                             │
└─────────────┼───────────────────────────────────────────────────────────┘
              │
              │ OAuth 2.0 / OIDC
              │
     ┌────────▼──────────┐
     │  Keycloak SSO     │
     │ (192.168.1.59)    │
     │  - Authentication │
     │  - Authorization  │
     │  - User Management│
     └───────────────────┘

┌─────────────────┼──────────────────────────────────────────────────────┐
│                 │  HTTP API       Python Server (192.168.1.90)         │
│  ┌──────────────▼──────────────────────────────────────────────┐      │
│  │                    FastAPI Application                       │      │
│  │  - REST API Endpoints                                        │      │
│  │  - Request Validation (Pydantic)                            │      │
│  │  - Job Submission                                            │      │
│  │  - Status Queries                                            │      │
│  │  - Result Retrieval                                          │      │
│  └──────────────┬──────────────────────────────────────────────┘      │
│                 │                                                       │
│                 │ Task Submission                                       │
│                 ▼                                                       │
│  ┌─────────────────────────────────────────────────────────────────┐  │
│  │                      Redis (Task Queue)                         │  │
│  │  Queue: mxa_ocr                                                 │  │
│  └─────────────────────────────┬───────────────────────────────────┘  │
│                                 │                                       │
│                                 │ Task Consumption                      │
│                                 ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────┐  │
│  │                    Celery Workers (x4)                          │  │
│  │  - Download from MinIO                                          │  │
│  │  - OCR Processing (Tesseract)                                   │  │
│  │  - PDF Processing (PyMuPDF)                                     │  │
│  │  - Result Storage                                               │  │
│  │  - Database Updates                                             │  │
│  └────┬────────────────────────────────┬────────────────────────────┘  │
│       │                                │                                │
│       │                                │                                │
│       ▼                                ▼                                │
│  ┌────────────┐                  ┌────────────┐                        │
│  │   MinIO    │                  │PostgreSQL  │                        │
│  │  Storage   │                  │  Updates   │                        │
│  │  Buckets:  │                  └────────────┘                        │
│  │  - input   │                                                         │
│  │  - output  │                                                         │
│  └────────────┘                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Component Description

### 1. PHP Web Frontend (App Server - 192.168.1.66)

**Technology Stack:**
- PHP 8.1+
- Apache 2.4 with mod_php
- Composer for dependency management

**Responsibilities:**
- User interface (HTML/CSS/JavaScript)
- Session management and authentication
- File upload handling
- API client for Python backend
- Database queries for user data and job status

**Key Components:**
- **Controllers**: Handle HTTP requests, route to appropriate services
- **Services**: Business logic layer, interact with repositories and external APIs
- **Repositories**: Data access layer, database queries
- **Models**: Data structures representing domain entities
- **Middleware**: Authentication, CSRF protection, role checking
- **Views**: HTML templates for rendering pages

**Security Features:**
- Secure session management (HttpOnly, Secure, SameSite cookies)
- CSRF token validation
- Input sanitization and validation
- SQL injection prevention (prepared statements)
- Role-based access control

### 2. Python Processing Backend (Python Server - 192.168.1.90)

**Technology Stack:**
- Python 3.10+
- FastAPI for REST API
- Celery for task queue
- Tesseract OCR
- PyMuPDF for PDF processing

**Components:**

#### 2a. FastAPI Application
**Responsibilities:**
- Expose REST API endpoints
- Validate incoming requests (Pydantic models)
- Submit tasks to Celery queue
- Return job status and results

**Endpoints:**
- `POST /api/v1/jobs` - Submit OCR job
- `GET /api/v1/jobs/{id}` - Get job status
- `GET /api/v1/results/{id}` - Get OCR results
- `GET /api/v1/health` - Health check

#### 2b. Celery Workers
**Responsibilities:**
- Process OCR jobs asynchronously
- Download files from MinIO
- Perform OCR extraction
- Upload results to MinIO
- Update job status in database

**Configuration:**
- Queue name: `mxa_ocr` (dedicated)
- Concurrency: 4 workers
- Task timeout: 30 minutes
- Retry policy: 3 attempts with backoff

### 3. PostgreSQL Database (App Server - 192.168.1.66)

**Database:** `mxa_ocr`  
**User:** `mxa_ocr_user`

**Tables:**
- `users` - User mapping from Keycloak
- `jobs` - OCR processing jobs
- `job_events` - Job lifecycle events
- `results` - OCR extraction results
- `exports` - Result export tracking
- `audit_logs` - Security audit trail
- `settings` - Application configuration

**Access Patterns:**
- PHP: Read/write for all tables
- Python: Read/write for jobs, job_events, results

### 4. MinIO Object Storage (Python Server - 192.168.1.90)

**Buckets:**
- `mxa-ocr-input` - Uploaded documents
- `mxa-ocr-output` - Processed results

**Directory Structure:**
```
mxa-ocr-input/
  └── {year}/{month}/{day}/{job_id}/original.{ext}

mxa-ocr-output/
  └── {year}/{month}/{day}/{job_id}/
      ├── result.txt
      ├── result.pdf
      ├── result.json
      └── metadata.json
```

**Retention:**
- 90 days (configurable)
- Automated cleanup via scheduled Celery task

### 5. Redis (Python Server - 192.168.1.90)

**Databases:**
- DB 0: Celery task queue (broker)
- DB 1: Celery result backend

**Usage:**
- Task queuing and distribution
- Result storage (temporary)
- Worker coordination

### 6. Keycloak SSO (SSO Server - 192.168.1.59)

**Client Configuration:**
- Client ID: `mxa-ocr-web`
- Protocol: OpenID Connect
- Flow: Authorization Code Flow
- Redirect URI: `https://ocr.gismartanalytics.com/auth/callback`

**Roles:**
- `ocr_admin` - Full access
- `ocr_user` - Submit and view own jobs
- `ocr_viewer` - Read-only access

## Data Flow

### 1. User Authentication Flow

```
User → PHP → Keycloak (login) → PHP → Database (user sync) → Dashboard
```

1. User visits application
2. PHP checks session
3. If not authenticated, redirect to Keycloak
4. User logs in at Keycloak
5. Keycloak redirects back with authorization code
6. PHP exchanges code for tokens
7. PHP fetches user info from Keycloak
8. PHP creates/updates user in local database
9. PHP sets session
10. User redirected to dashboard

### 2. File Upload and Processing Flow

```
User → PHP → MinIO (upload) → Database (job record) → Python API → 
Celery Queue → Worker → OCR Processing → MinIO (results) → Database (results)
```

1. User uploads file via PHP UI
2. PHP validates file (size, type)
3. PHP uploads file to MinIO input bucket
4. PHP creates job record in database
5. PHP calls Python API to submit job
6. Python API validates request and enqueues Celery task
7. Celery worker picks up task from queue
8. Worker downloads file from MinIO
9. Worker performs OCR processing
10. Worker uploads results to MinIO output bucket
11. Worker saves results to database
12. Worker updates job status to "completed"
13. User polls PHP for status or receives notification
14. User downloads results via PHP

### 3. Result Retrieval Flow

```
User → PHP → Database (check status) → PHP → MinIO (fetch file) → User
```

1. User requests results
2. PHP checks job status in database
3. If completed, PHP fetches result paths from database
4. PHP generates pre-signed URL or downloads from MinIO
5. PHP serves file to user
6. PHP logs download in audit_logs table

## Design Decisions

### 1. Multi-Tier Architecture

**Decision:** Separate PHP frontend and Python backend.

**Rationale:**
- PHP excels at web UI and session management
- Python excels at OCR processing and scientific computing
- Separation of concerns improves maintainability
- Independent scaling of frontend and backend

### 2. Asynchronous Processing

**Decision:** Use Celery for background job processing.

**Rationale:**
- OCR processing can take minutes for large documents
- Synchronous processing would block web requests
- Queue-based processing enables horizontal scaling
- Retry logic for fault tolerance

### 3. Dedicated Queue

**Decision:** Use dedicated queue name (`mxa_ocr`).

**Rationale:**
- Isolation from other products
- Independent scaling
- No cross-product interference
- Clear resource allocation

### 4. MinIO for Storage

**Decision:** Use MinIO instead of local filesystem.

**Rationale:**
- S3-compatible API
- Scalable and distributed
- Easy backup and replication
- Object versioning support
- Better than NFS for performance

### 5. PostgreSQL Over MySQL

**Decision:** Use PostgreSQL for database.

**Rationale:**
- Better JSON support (JSONB)
- Full-text search capabilities
- Advanced indexing options
- Better for analytics queries
- ACID compliance

### 6. Keycloak for SSO

**Decision:** Use Keycloak instead of custom auth.

**Rationale:**
- Enterprise-grade authentication
- OIDC/OAuth2 standard protocols
- Centralized user management
- Multi-factor authentication support
- Single sign-on across products

## Scalability Considerations

### Horizontal Scaling

**PHP Frontend:**
- Add more Apache servers behind load balancer
- Session storage in Redis or database (not files)
- Stateless application design

**Python Workers:**
- Add more Celery workers
- Increase concurrency per worker
- Distribute across multiple servers

**Database:**
- Read replicas for queries
- Connection pooling
- Query optimization

**MinIO:**
- Distributed MinIO cluster
- Multiple nodes for redundancy

### Vertical Scaling

- Increase worker concurrency
- Increase database connection pool
- Optimize OCR parameters (DPI, language models)

## Security Architecture

### Network Security
- HTTPS everywhere (TLS 1.2+)
- Server-to-server communication on private network
- Firewall rules restrict access

### Application Security
- Input validation at all layers
- Output encoding to prevent XSS
- Prepared statements to prevent SQL injection
- CSRF tokens on state-changing operations
- Secure session management

### Data Security
- Passwords never stored (Keycloak handles auth)
- Secrets in environment variables, not code
- Audit logging for compliance
- File upload validation
- Regular security updates

### Access Control
- Role-based access control (RBAC)
- Principle of least privilege
- Session timeout
- Token expiration

## Monitoring and Observability

### Logging
- Application logs (structured JSON)
- Access logs (Apache)
- Error logs (PHP, Python)
- Audit logs (database)

### Metrics
- API response times
- Queue depth
- Worker utilization
- OCR processing times
- Database query performance

### Health Checks
- `/api/v1/health` - API health
- Database connectivity
- Redis connectivity
- MinIO connectivity

## Disaster Recovery

### Backup Strategy
- Database: Daily full backups
- MinIO: Object versioning enabled
- Configuration: Version controlled

### Recovery Procedures
- Database restore from backup
- MinIO object recovery
- Service restart procedures

## Future Enhancements

1. **Caching Layer**: Redis cache for frequent queries
2. **Message Queue**: RabbitMQ for more complex workflows
3. **Search Engine**: Elasticsearch for full-text search
4. **Monitoring**: Prometheus + Grafana
5. **API Gateway**: Kong or similar for rate limiting
6. **CDN**: CloudFlare for static assets

## Related Documentation

- [Deployment Guide](deployment.md)
- [API Reference](api.md)
- [Database Schema](database.md)
- [Authentication](authentication.md)
