# MXA OCR - Database Documentation

## Overview

The MXA OCR application uses PostgreSQL 14+ for data storage.

**Database:** `mxa_ocr`  
**User:** `mxa_ocr_user`  
**Server:** 192.168.1.66

## Schema

See [database/schema.sql](../database/schema.sql) for complete schema.

### Tables

- `users` - User accounts from Keycloak
- `jobs` - OCR processing jobs
- `job_events` - Job lifecycle events
- `results` - OCR extraction results
- `exports` - Result downloads
- `audit_logs` - Security audit trail
- `settings` - Application settings

### Indexes

See [database/migrations/002_add_indexes.sql](../database/migrations/002_add_indexes.sql)

## Migrations

Migrations are in `database/migrations/` directory.

Run in order:
1. 001_initial_schema.sql
2. 002_add_indexes.sql

## Backup and Restore

### Backup
```bash
pg_dump -U mxa_ocr_user mxa_ocr > backup.sql
```

### Restore
```bash
psql -U mxa_ocr_user mxa_ocr < backup.sql
```

## Maintenance

### Vacuum
```bash
VACUUM ANALYZE;
```

### Cleanup Old Jobs
```sql
SELECT cleanup_old_jobs(90);
```

## Related Documentation
- [Architecture](architecture.md)
- [Deployment](deployment.md)
