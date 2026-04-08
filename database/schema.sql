-- ============================================================
-- OCR Platform - PostgreSQL Schema
-- Server: 192.168.1.66
-- ============================================================

BEGIN;

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- ENUM TYPES
-- ============================================================

CREATE TYPE job_status AS ENUM (
    'pending',
    'queued',
    'processing',
    'completed',
    'failed',
    'cancelled'
);

CREATE TYPE upload_type AS ENUM (
    'pdf',
    'image'
);

CREATE TYPE log_level AS ENUM (
    'info',
    'warning',
    'error',
    'debug'
);

-- ============================================================
-- USERS_LOCAL
-- Synced from SSO, stores local user profile/state
-- ============================================================

CREATE TABLE users_local (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sso_user_id     VARCHAR(255) NOT NULL UNIQUE,
    email           VARCHAR(320) NOT NULL,
    display_name    VARCHAR(255) NOT NULL DEFAULT '',
    role            VARCHAR(50) NOT NULL DEFAULT 'user',
    avatar_url      VARCHAR(512),
    last_login_at   TIMESTAMPTZ,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_local_sso_user_id ON users_local (sso_user_id);
CREATE INDEX idx_users_local_email ON users_local (email);
CREATE INDEX idx_users_local_is_active ON users_local (is_active);

-- ============================================================
-- UPLOADS
-- Tracks every file uploaded by a user
-- ============================================================

CREATE TABLE uploads (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID NOT NULL REFERENCES users_local(id) ON DELETE CASCADE,
    original_filename   VARCHAR(512) NOT NULL,
    stored_filename     VARCHAR(512) NOT NULL,
    mime_type           VARCHAR(128) NOT NULL,
    file_size_bytes     BIGINT NOT NULL DEFAULT 0,
    upload_type         upload_type NOT NULL,
    page_count          INT,
    minio_bucket        VARCHAR(128) NOT NULL DEFAULT 'ocr-uploads',
    minio_object_key    VARCHAR(1024) NOT NULL,
    checksum_sha256     VARCHAR(64),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_uploads_user_id ON uploads (user_id);
CREATE INDEX idx_uploads_created_at ON uploads (created_at DESC);

-- ============================================================
-- OCR_JOBS
-- Represents a processing job submitted to the Python backend
-- ============================================================

CREATE TABLE ocr_jobs (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID NOT NULL REFERENCES users_local(id) ON DELETE CASCADE,
    upload_id           UUID NOT NULL REFERENCES uploads(id) ON DELETE CASCADE,
    status              job_status NOT NULL DEFAULT 'pending',
    priority            INT NOT NULL DEFAULT 0,
    engine              VARCHAR(64) NOT NULL DEFAULT 'tesseract',
    language            VARCHAR(16) NOT NULL DEFAULT 'eng',
    celery_task_id      VARCHAR(255),
    progress_percent    SMALLINT NOT NULL DEFAULT 0 CHECK (progress_percent BETWEEN 0 AND 100),
    pages_processed     INT NOT NULL DEFAULT 0,
    pages_total         INT NOT NULL DEFAULT 0,
    started_at          TIMESTAMPTZ,
    completed_at        TIMESTAMPTZ,
    error_message       TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ocr_jobs_user_id ON ocr_jobs (user_id);
CREATE INDEX idx_ocr_jobs_status ON ocr_jobs (status);
CREATE INDEX idx_ocr_jobs_created_at ON ocr_jobs (created_at DESC);
CREATE INDEX idx_ocr_jobs_upload_id ON ocr_jobs (upload_id);

-- ============================================================
-- OCR_RESULTS
-- Stores extracted text/data from completed OCR jobs
-- ============================================================

CREATE TABLE ocr_results (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id              UUID NOT NULL REFERENCES ocr_jobs(id) ON DELETE CASCADE,
    page_number         INT,
    extracted_text      TEXT NOT NULL DEFAULT '',
    confidence_score    NUMERIC(5,2),
    word_count          INT NOT NULL DEFAULT 0,
    minio_result_key    VARCHAR(1024),
    format              VARCHAR(32) NOT NULL DEFAULT 'text',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ocr_results_job_id ON ocr_results (job_id);
CREATE INDEX idx_ocr_results_page_number ON ocr_results (job_id, page_number);

-- ============================================================
-- JOB_LOGS
-- Audit trail for every state change / event in a job
-- ============================================================

CREATE TABLE job_logs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id          UUID NOT NULL REFERENCES ocr_jobs(id) ON DELETE CASCADE,
    level           log_level NOT NULL DEFAULT 'info',
    message         TEXT NOT NULL,
    context         JSONB,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_job_logs_job_id ON job_logs (job_id);
CREATE INDEX idx_job_logs_created_at ON job_logs (created_at DESC);
CREATE INDEX idx_job_logs_level ON job_logs (level);

-- ============================================================
-- TRIGGER: auto-update updated_at columns
-- ============================================================

CREATE OR REPLACE FUNCTION trigger_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_users_local_updated_at
    BEFORE UPDATE ON users_local
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

CREATE TRIGGER set_ocr_jobs_updated_at
    BEFORE UPDATE ON ocr_jobs
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

COMMIT;
