-- ============================================================================
-- Migration: 002 - Add Indexes
-- ============================================================================
-- Product: MXA OCR
-- Date: 2026-04-10
-- Description: Add performance indexes to all tables
-- ============================================================================

\echo 'Running migration 002: Add Indexes...'

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

\echo 'Migration 002 completed successfully!'
