# MXA OCR - API Documentation

## Overview

The MXA OCR Python backend exposes a REST API for job submission, status checking, and result retrieval. This document describes all available endpoints.

**Base URL:** `http://192.168.1.90:8100`  
**Version:** v1  
**Format:** JSON

## Authentication

Currently, the API uses optional API key authentication. If configured, include the API key in requests:

```
X-API-Key: your-api-key-here
```

Future versions may implement OAuth2 bearer tokens.

## Endpoints

### Health Endpoints

#### GET /api/v1/health

Basic health check.

**Response:** `200 OK`
```json
{
  "status": "healthy",
  "application": "MXA OCR Backend",
  "version": "1.0.0",
  "environment": "production",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

#### GET /api/v1/health/detailed

Detailed health check with system metrics.

**Response:** `200 OK`
```json
{
  "status": "healthy",
  "application": "MXA OCR Backend",
  "version": "1.0.0",
  "environment": "production",
  "timestamp": "2024-01-15T10:30:00Z",
  "system": {
    "platform": "Linux",
    "python_version": "3.10.12",
    "cpu_percent": 15.2,
    "memory": {
      "total_gb": 16.0,
      "available_gb": 8.5,
      "percent_used": 46.9
    },
    "disk": {
      "total_gb": 500.0,
      "free_gb": 350.0,
      "percent_used": 30.0
    }
  },
  "configuration": {
    "queue_name": "mxa_ocr",
    "worker_concurrency": 4,
    "max_file_size_mb": 50
  }
}
```

#### GET /api/v1/ready

Readiness check for load balancers.

**Response:** `200 OK`
```json
{
  "ready": true,
  "timestamp": "2024-01-15T10:30:00Z"
}
```

---

### Job Management

#### POST /api/v1/jobs

Submit a new OCR processing job.

**Request Body:**
```json
{
  "job_id": "123e4567-e89b-12d3-a456-426614174000",
  "user_id": "user-uuid-here",
  "original_filename": "document.pdf",
  "file_size": 1024000,
  "file_type": "application/pdf",
  "minio_input_path": "2024/01/15/job-id/document.pdf",
  "priority": 5,
  "metadata": {
    "language": "eng",
    "dpi": 300
  }
}
```

**Fields:**
- `job_id` (string, required): Unique job identifier (UUID)
- `user_id` (string, required): User who submitted the job
- `original_filename` (string, required): Original file name
- `file_size` (integer, required): File size in bytes
- `file_type` (string, required): MIME type
- `minio_input_path` (string, required): Path in MinIO input bucket
- `priority` (integer, optional): Job priority 1-9, default 5
- `metadata` (object, optional): Additional parameters

**Response:** `201 Created`
```json
{
  "job_id": "123e4567-e89b-12d3-a456-426614174000",
  "status": "pending",
  "message": "Job submitted successfully",
  "task_id": "celery-task-id-123"
}
```

**Error Responses:**

`400 Bad Request` - Invalid request data
```json
{
  "error": "Validation error",
  "detail": "minio_input_path is required"
}
```

`500 Internal Server Error` - Server error
```json
{
  "error": "Internal server error",
  "message": "Failed to submit job"
}
```

#### GET /api/v1/jobs/{job_id}

Get status of a specific job.

**Path Parameters:**
- `job_id` (string): Job UUID

**Response:** `200 OK`
```json
{
  "job_id": "123e4567-e89b-12d3-a456-426614174000",
  "status": "processing",
  "message": "Job is being processed"
}
```

**Possible Status Values:**
- `pending` - Job queued, waiting for worker
- `processing` - Job is being processed
- `completed` - Job completed successfully
- `failed` - Job failed with error
- `cancelled` - Job was cancelled

#### GET /api/v1/jobs

List jobs with optional filtering.

**Query Parameters:**
- `user_id` (string, optional): Filter by user
- `status` (string, optional): Filter by status
- `limit` (integer, optional): Results per page (default: 50, max: 100)
- `offset` (integer, optional): Pagination offset (default: 0)

**Example Request:**
```
GET /api/v1/jobs?user_id=user-123&status=completed&limit=20&offset=0
```

**Response:** `200 OK`
```json
{
  "jobs": [],
  "total": 0,
  "limit": 20,
  "offset": 0
}
```

#### DELETE /api/v1/jobs/{job_id}

Cancel a pending or processing job.

**Path Parameters:**
- `job_id` (string): Job UUID

**Response:** `204 No Content`

**Error Responses:**

`404 Not Found` - Job not found
```json
{
  "error": "Not found",
  "message": "Job not found"
}
```

`400 Bad Request` - Job cannot be cancelled
```json
{
  "error": "Invalid operation",
  "message": "Job already completed, cannot cancel"
}
```

---

### Results

#### GET /api/v1/results/{job_id}

Get OCR results for a completed job.

**Path Parameters:**
- `job_id` (string): Job UUID

**Response:** `200 OK`
```json
{
  "job_id": "123e4567-e89b-12d3-a456-426614174000",
  "extracted_text": "This is the extracted text from the document...",
  "page_count": 5,
  "confidence_score": 95.8,
  "language_detected": "eng",
  "processing_time_ms": 15000,
  "output_formats": [
    {"format": "txt", "path": "2024/01/15/job-id/result.txt"},
    {"format": "pdf", "path": "2024/01/15/job-id/result.pdf"},
    {"format": "json", "path": "2024/01/15/job-id/result.json"}
  ],
  "metadata": {
    "tesseract_version": "4.1.1",
    "dpi": 300,
    "ocr_engine": "tesseract"
  },
  "created_at": "2024-01-15T10:30:00Z"
}
```

**Error Responses:**

`404 Not Found` - Results not found
```json
{
  "error": "Not found",
  "detail": "Results not found for job 123e4567-e89b-12d3-a456-426614174000"
}
```

`400 Bad Request` - Job not completed
```json
{
  "error": "Invalid operation",
  "message": "Job is still processing"
}
```

---

## Error Handling

All errors follow a consistent format:

```json
{
  "error": "Error type",
  "message": "Human-readable error message",
  "detail": "Additional details (optional)"
}
```

### HTTP Status Codes

- `200 OK` - Successful GET request
- `201 Created` - Successful POST request
- `204 No Content` - Successful DELETE request
- `400 Bad Request` - Invalid request data
- `401 Unauthorized` - Missing or invalid API key
- `404 Not Found` - Resource not found
- `422 Unprocessable Entity` - Validation error
- `500 Internal Server Error` - Server error

---

## Rate Limiting

Currently not implemented. Future versions will include rate limiting:

- 100 requests per hour per IP
- 1000 requests per day per user

Rate limit headers will be included:
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1640000000
```

---

## Versioning

The API uses URL versioning (`/api/v1/`). Future versions will be released as `/api/v2/` etc.

Breaking changes will only occur in major versions. Minor versions maintain backward compatibility.

---

## Examples

### Submit Job (cURL)

```bash
curl -X POST http://192.168.1.90:8100/api/v1/jobs \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-api-key" \
  -d '{
    "job_id": "123e4567-e89b-12d3-a456-426614174000",
    "user_id": "user-123",
    "original_filename": "document.pdf",
    "file_size": 1024000,
    "file_type": "application/pdf",
    "minio_input_path": "2024/01/15/job-id/document.pdf",
    "priority": 5
  }'
```

### Check Status (cURL)

```bash
curl http://192.168.1.90:8100/api/v1/jobs/123e4567-e89b-12d3-a456-426614174000
```

### Get Results (cURL)

```bash
curl http://192.168.1.90:8100/api/v1/results/123e4567-e89b-12d3-a456-426614174000
```

### Submit Job (Python)

```python
import requests

url = "http://192.168.1.90:8100/api/v1/jobs"
headers = {
    "Content-Type": "application/json",
    "X-API-Key": "your-api-key"
}
data = {
    "job_id": "123e4567-e89b-12d3-a456-426614174000",
    "user_id": "user-123",
    "original_filename": "document.pdf",
    "file_size": 1024000,
    "file_type": "application/pdf",
    "minio_input_path": "2024/01/15/job-id/document.pdf",
    "priority": 5
}

response = requests.post(url, json=data, headers=headers)
print(response.json())
```

### Submit Job (PHP - Internal Client)

```php
use MxaOcr\Services\PythonApiClient;

$client = new PythonApiClient();
$result = $client->submitJob([
    'job_id' => '123e4567-e89b-12d3-a456-426614174000',
    'user_id' => $userId,
    'original_filename' => 'document.pdf',
    'file_size' => 1024000,
    'file_type' => 'application/pdf',
    'minio_input_path' => '2024/01/15/job-id/document.pdf',
    'priority' => 5,
]);
```

---

## Webhooks (Future)

Future versions may support webhooks for job status updates:

```json
{
  "event": "job.completed",
  "job_id": "123e4567-e89b-12d3-a456-426614174000",
  "status": "completed",
  "timestamp": "2024-01-15T10:35:00Z"
}
```

---

## Related Documentation

- [Architecture](architecture.md)
- [Authentication](authentication.md)
- [Deployment](deployment.md)
