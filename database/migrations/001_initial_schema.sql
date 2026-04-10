-- ============================================================================
-- Migration: 001 - Initial Schema
-- ============================================================================
-- Product: MXA OCR
-- Date: 2026-04-10
-- Description: Create initial database schema with all core tables
-- ============================================================================

\echo 'Running migration 001: Initial Schema...'

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Create ENUMS
CREATE TYPE job_status AS ENUM ('pending', 'processing', 'completed', 'failed', 'cancelled');
CREATE TYPE job_event_type AS ENUM ('submitted', 'queued', 'started', 'progress', 'completed', 'failed', 'cancelled');
CREATE TYPE export_format AS ENUM ('txt', 'pdf', 'json', 'csv');

-- Create users table
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    keycloak_id     VARCHAR(255) NOT NULL UNIQUE,
    email           VARCHAR(255) NOT NULL,
    username        VARCHAR(100) NOT NULL,
    full_name       VARCHAR(255),
    roles           JSONB DEFAULT '[]'::jsonb,
    is_active       BOOLEAN DEFAULT true,
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_login_at   TIMESTAMP WITH TIME ZONE
);

-- Create jobs table
CREATE TABLE jobs (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status              job_status NOT NULL DEFAULT 'pending',
    priority            INTEGER DEFAULT 5,
    original_filename   VARCHAR(500) NOT NULL,
    file_size           BIGINT NOT NULL,
    file_type           VARCHAR(100) NOT NULL,
    minio_input_path    VARCHAR(1000) NOT NULL,
    minio_output_path   VARCHAR(1000),
    submitted_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    started_at          TIMESTAMP WITH TIME ZONE,
    completed_at        TIMESTAMP WITH TIME ZONE,
    error_message       TEXT,
    retry_count         INTEGER DEFAULT 0,
    metadata            JSONB DEFAULT '{}'::jsonb,
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create job_events table
CREATE TABLE job_events (
    id              BIGSERIAL PRIMARY KEY,
    job_id          UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    event_type      job_event_type NOT NULL,
    message         VARCHAR(1000),
    details         JSONB DEFAULT '{}'::jsonb,
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create results table
CREATE TABLE results (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id              UUID NOT NULL UNIQUE REFERENCES jobs(id) ON DELETE CASCADE,
    extracted_text      TEXT,
    page_count          INTEGER,
    confidence_score    DECIMAL(5,2),
    language_detected   VARCHAR(50),
    processing_time_ms  INTEGER,
    output_formats      JSONB DEFAULT '[]'::jsonb,
    metadata            JSONB DEFAULT '{}'::jsonb,
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create exports table
CREATE TABLE exports (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    result_id       UUID NOT NULL REFERENCES results(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    format          export_format NOT NULL,
    minio_path      VARCHAR(1000) NOT NULL,
    file_size       BIGINT,
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    downloaded_at   TIMESTAMP WITH TIME ZONE
);

-- Create audit_logs table
CREATE TABLE audit_logs (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID REFERENCES users(id) ON DELETE SET NULL,
    action          VARCHAR(100) NOT NULL,
    resource_type   VARCHAR(100),
    resource_id     UUID,
    ip_address      INET,
    user_agent      TEXT,
    details         JSONB DEFAULT '{}'::jsonb,
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create settings table
CREATE TABLE settings (
    id              SERIAL PRIMARY KEY,
    key             VARCHAR(100) NOT NULL UNIQUE,
    value           JSONB NOT NULL,
    category        VARCHAR(100),
    description     TEXT,
    updated_by      UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply triggers
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_jobs_updated_at BEFORE UPDATE ON jobs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_settings_updated_at BEFORE UPDATE ON settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert default settings
INSERT INTO settings (key, value, category, description) VALUES
    ('max_file_size_mb', '50', 'upload', 'Maximum file upload size in megabytes'),
    ('allowed_file_types', '["application/pdf", "image/png", "image/jpeg", "image/tiff"]', 'upload', 'Allowed MIME types for upload'),
    ('ocr_default_language', '"eng"', 'ocr', 'Default OCR language code'),
    ('ocr_supported_languages', '["eng", "afr", "ara", "fra", "deu", "spa"]', 'ocr', 'Supported OCR language codes'),
    ('retention_days', '90', 'storage', 'Days to retain processed files'),
    ('max_jobs_per_user', '10', 'limits', 'Maximum concurrent jobs per user'),
    ('enable_registration', 'false', 'auth', 'Allow user self-registration');

\echo 'Migration 001 completed successfully!'
