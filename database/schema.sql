-- ============================================================================
-- MXA OCR - Database Schema
-- ============================================================================
-- Product: MXA OCR
-- Database: mxa_ocr
-- Database User: mxa_ocr_user
-- PostgreSQL Version: 14+
--
-- This schema is specific to the MXA OCR product only.
-- Do not share this database or schema with other products.
-- ============================================================================

-- Create database (run as postgres superuser)
-- CREATE DATABASE mxa_ocr OWNER mxa_ocr_user ENCODING 'UTF8';
-- \c mxa_ocr

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable pg_trgm for text search
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ============================================================================
-- ENUMS
-- ============================================================================

CREATE TYPE job_status AS ENUM (
    'pending',      -- Job created, waiting to be picked up
    'processing',   -- Job is being processed
    'completed',    -- Job completed successfully
    'failed',       -- Job failed with error
    'cancelled'     -- Job was cancelled by user
);

CREATE TYPE job_event_type AS ENUM (
    'submitted',    -- Job was submitted
    'queued',       -- Job was queued
    'started',      -- Processing started
    'progress',     -- Progress update
    'completed',    -- Processing completed
    'failed',       -- Processing failed
    'cancelled'     -- Job was cancelled
);

CREATE TYPE export_format AS ENUM (
    'txt',          -- Plain text
    'pdf',          -- Searchable PDF
    'json',         -- JSON with metadata
    'csv'           -- CSV format
);

-- ============================================================================
-- TABLES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Users Table (local mapping from Keycloak)
-- ----------------------------------------------------------------------------
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

COMMENT ON TABLE users IS 'Local user mapping from Keycloak SSO';
COMMENT ON COLUMN users.keycloak_id IS 'Unique ID from Keycloak (sub claim)';
COMMENT ON COLUMN users.roles IS 'Roles array from Keycloak token claims';

-- ----------------------------------------------------------------------------
-- Jobs Table (OCR processing jobs)
-- ----------------------------------------------------------------------------
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

COMMENT ON TABLE jobs IS 'OCR processing jobs queue and history';
COMMENT ON COLUMN jobs.priority IS 'Job priority: 1=low, 5=normal, 9=high';
COMMENT ON COLUMN jobs.metadata IS 'Additional job parameters (language, dpi, etc.)';

-- ----------------------------------------------------------------------------
-- Job Events Table (job processing history/logs)
-- ----------------------------------------------------------------------------
CREATE TABLE job_events (
    id              BIGSERIAL PRIMARY KEY,
    job_id          UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    event_type      job_event_type NOT NULL,
    message         VARCHAR(1000),
    details         JSONB DEFAULT '{}'::jsonb,
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE job_events IS 'Event log for job lifecycle tracking';
COMMENT ON COLUMN job_events.details IS 'Additional event data (progress %, error details, etc.)';

-- ----------------------------------------------------------------------------
-- Results Table (OCR extraction results)
-- ----------------------------------------------------------------------------
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

COMMENT ON TABLE results IS 'OCR extraction results and metadata';
COMMENT ON COLUMN results.confidence_score IS 'Average OCR confidence (0-100)';
COMMENT ON COLUMN results.output_formats IS 'Available output formats with paths';
COMMENT ON COLUMN results.metadata IS 'OCR engine metadata (version, settings, etc.)';

-- ----------------------------------------------------------------------------
-- Exports Table (result downloads/exports)
-- ----------------------------------------------------------------------------
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

COMMENT ON TABLE exports IS 'Track result exports and downloads';

-- ----------------------------------------------------------------------------
-- Audit Logs Table (security and compliance auditing)
-- ----------------------------------------------------------------------------
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

COMMENT ON TABLE audit_logs IS 'Audit trail for security and compliance';
COMMENT ON COLUMN audit_logs.action IS 'Action performed (e.g., login, upload, delete)';
COMMENT ON COLUMN audit_logs.details IS 'Additional context (old/new values, etc.)';

-- ----------------------------------------------------------------------------
-- Settings Table (application configuration)
-- ----------------------------------------------------------------------------
CREATE TABLE settings (
    id              SERIAL PRIMARY KEY,
    key             VARCHAR(100) NOT NULL UNIQUE,
    value           JSONB NOT NULL,
    category        VARCHAR(100),
    description     TEXT,
    updated_by      UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE settings IS 'Application settings and configuration';

-- ============================================================================
-- INDEXES
-- ============================================================================

-- Users indexes
CREATE INDEX idx_users_keycloak_id ON users(keycloak_id);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_is_active ON users(is_active);

-- Jobs indexes
CREATE INDEX idx_jobs_user_id ON jobs(user_id);
CREATE INDEX idx_jobs_status ON jobs(status);
CREATE INDEX idx_jobs_submitted_at ON jobs(submitted_at DESC);
CREATE INDEX idx_jobs_user_status ON jobs(user_id, status);
CREATE INDEX idx_jobs_priority_status ON jobs(priority DESC, status) WHERE status = 'pending';

-- Job events indexes
CREATE INDEX idx_job_events_job_id ON job_events(job_id);
CREATE INDEX idx_job_events_created_at ON job_events(created_at DESC);

-- Results indexes
CREATE INDEX idx_results_job_id ON results(job_id);
CREATE INDEX idx_results_created_at ON results(created_at DESC);
CREATE INDEX idx_results_text_search ON results USING gin(to_tsvector('english', extracted_text));

-- Exports indexes
CREATE INDEX idx_exports_result_id ON exports(result_id);
CREATE INDEX idx_exports_user_id ON exports(user_id);
CREATE INDEX idx_exports_created_at ON exports(created_at DESC);

-- Audit logs indexes
CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
CREATE INDEX idx_audit_logs_resource ON audit_logs(resource_type, resource_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at DESC);

-- Settings indexes
CREATE INDEX idx_settings_category ON settings(category);

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to relevant tables
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_jobs_updated_at BEFORE UPDATE ON jobs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_settings_updated_at BEFORE UPDATE ON settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- DEFAULT DATA
-- ============================================================================

-- Default settings
INSERT INTO settings (key, value, category, description) VALUES
    ('max_file_size_mb', '50', 'upload', 'Maximum file upload size in megabytes'),
    ('allowed_file_types', '["application/pdf", "image/png", "image/jpeg", "image/tiff"]', 'upload', 'Allowed MIME types for upload'),
    ('ocr_default_language', '"eng"', 'ocr', 'Default OCR language code'),
    ('ocr_supported_languages', '["eng", "afr", "ara", "fra", "deu", "spa"]', 'ocr', 'Supported OCR language codes'),
    ('retention_days', '90', 'storage', 'Days to retain processed files'),
    ('max_jobs_per_user', '10', 'limits', 'Maximum concurrent jobs per user'),
    ('enable_registration', 'false', 'auth', 'Allow user self-registration')
ON CONFLICT (key) DO NOTHING;

-- ============================================================================
-- PERMISSIONS
-- ============================================================================

-- Grant permissions to mxa_ocr_user
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO mxa_ocr_user;
-- GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO mxa_ocr_user;
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO mxa_ocr_user;

-- ============================================================================
-- VIEWS
-- ============================================================================

-- View for job statistics
CREATE OR REPLACE VIEW job_statistics AS
SELECT 
    u.id as user_id,
    u.username,
    COUNT(*) as total_jobs,
    COUNT(*) FILTER (WHERE j.status = 'pending') as pending_jobs,
    COUNT(*) FILTER (WHERE j.status = 'processing') as processing_jobs,
    COUNT(*) FILTER (WHERE j.status = 'completed') as completed_jobs,
    COUNT(*) FILTER (WHERE j.status = 'failed') as failed_jobs,
    AVG(EXTRACT(EPOCH FROM (j.completed_at - j.started_at))) FILTER (WHERE j.status = 'completed') as avg_processing_time_sec
FROM users u
LEFT JOIN jobs j ON u.id = j.user_id
GROUP BY u.id, u.username;

COMMENT ON VIEW job_statistics IS 'User job statistics summary';

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Function to get pending jobs count
CREATE OR REPLACE FUNCTION get_pending_jobs_count()
RETURNS INTEGER AS $$
BEGIN
    RETURN (SELECT COUNT(*) FROM jobs WHERE status = 'pending');
END;
$$ LANGUAGE plpgsql;

-- Function to clean old jobs (for maintenance)
CREATE OR REPLACE FUNCTION cleanup_old_jobs(days_to_keep INTEGER DEFAULT 90)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    WITH deleted AS (
        DELETE FROM jobs
        WHERE status IN ('completed', 'failed', 'cancelled')
        AND completed_at < CURRENT_TIMESTAMP - (days_to_keep || ' days')::INTERVAL
        RETURNING *
    )
    SELECT COUNT(*) INTO deleted_count FROM deleted;
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION cleanup_old_jobs IS 'Delete jobs older than specified days';

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================
