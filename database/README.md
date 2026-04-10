# MXA OCR - Database Documentation

This directory contains all database-related files for the MXA OCR product.

## Database Configuration

- **Database Name**: `mxa_ocr`
- **Database User**: `mxa_ocr_user`
- **PostgreSQL Version**: 14+
- **Server**: 192.168.1.66

## Files

- `schema.sql` - Complete database schema with all tables, indexes, and functions
- `migrations/` - Sequential migration scripts
- `seed.sql` - Optional sample data for development (not created yet)

## Quick Setup

### 1. Create Database and User

Connect as PostgreSQL superuser:

```bash
sudo -u postgres psql
```

Run these commands:

```sql
-- Create user
CREATE USER mxa_ocr_user WITH PASSWORD 'your_password_here';

-- Create database
CREATE DATABASE mxa_ocr OWNER mxa_ocr_user ENCODING 'UTF8';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE mxa_ocr TO mxa_ocr_user;

-- Connect to database
\c mxa_ocr

-- Grant schema privileges
GRANT ALL PRIVILEGES ON SCHEMA public TO mxa_ocr_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO mxa_ocr_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO mxa_ocr_user;
```

### 2. Run Schema

```bash
psql -U mxa_ocr_user -d mxa_ocr -f schema.sql
```

Or run migrations sequentially:

```bash
psql -U mxa_ocr_user -d mxa_ocr -f migrations/001_initial_schema.sql
psql -U mxa_ocr_user -d mxa_ocr -f migrations/002_add_indexes.sql
```

## Tables Overview

| Table | Purpose |
|-------|---------|
| `users` | User mapping from Keycloak SSO |
| `jobs` | OCR processing jobs queue |
| `job_events` | Job lifecycle event log |
| `results` | OCR extraction results |
| `exports` | Result export/download tracking |
| `audit_logs` | Security and compliance audit trail |
| `settings` | Application configuration |

## Migrations

Migrations are numbered sequentially and should be run in order:

1. `001_initial_schema.sql` - Creates all tables, enums, and triggers
2. `002_add_indexes.sql` - Adds performance indexes

## Backup and Restore

### Backup

```bash
pg_dump -U mxa_ocr_user -d mxa_ocr -F c -f backups/mxa_ocr_$(date +%Y%m%d_%H%M%S).dump
```

### Restore

```bash
pg_restore -U mxa_ocr_user -d mxa_ocr -c backups/mxa_ocr_YYYYMMDD_HHMMSS.dump
```

## Maintenance

### Clean Old Jobs

```sql
-- Delete completed/failed jobs older than 90 days
SELECT cleanup_old_jobs(90);
```

### View Statistics

```sql
-- View job statistics per user
SELECT * FROM job_statistics;
```

### Check Pending Jobs

```sql
SELECT get_pending_jobs_count();
```

## Security Notes

- Never commit database dumps or backups to version control
- Use strong passwords for database user
- Restrict database access to application servers only
- Regular backups are essential
- Monitor audit_logs for security events

## Related Documentation

See [docs/database.md](../docs/database.md) for detailed schema documentation.
