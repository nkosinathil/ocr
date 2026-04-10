# MXA OCR - Migration Notes

## Overview

This document provides guidance for migrating existing OCR systems to MXA OCR.

## From Desktop Application

If you currently have a Qt/desktop-based OCR application:

### Data Migration

1. Export existing processing history
2. Import users into Keycloak
3. Map existing data to new schema
4. Import into PostgreSQL

### Process Migration

1. Identify reusable OCR processing logic
2. Integrate into Python backend
3. Adapt for async processing
4. Test thoroughly

## From Other Web Applications

### Database Migration

- Map existing schema to MXA OCR schema
- Write migration scripts
- Test with sample data

### Authentication Migration

- Export users to Keycloak
- Configure role mappings
- Test login flow

### File Migration

- Move files to MinIO buckets
- Update paths in database
- Verify accessibility

## Rollback Plan

Always have a rollback plan:

1. Backup current system
2. Test migration in staging
3. Plan rollback procedures
4. Document recovery steps

## Post-Migration

- Verify all data migrated correctly
- Test all functionality
- Monitor for issues
- Gather user feedback

## Related Documentation
- [Deployment](deployment.md)
- [Database](database.md)
