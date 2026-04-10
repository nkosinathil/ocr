# MXA OCR - Configuration Guide

## Overview

This document describes all configuration options for the MXA OCR application.

## PHP Configuration

See `php-app/.env.example` for all PHP configuration options.

Key sections:
- Application settings
- Database connection
- Keycloak SSO
- Python API client
- MinIO storage
- Session management
- Security settings
- File upload limits

## Python Configuration

See `python-backend/.env.example` for all Python configuration options.

Key sections:
- Application settings
- Database connection
- Redis connection
- Celery configuration
- MinIO storage
- OCR settings
- File processing
- Logging

## Environment-Specific Configuration

### Development
- Debug mode enabled
- Verbose logging
- Local services

### Production
- Debug mode disabled
- Error logging only
- Remote services
- SSL/TLS enabled

## Related Documentation
- [Deployment Guide](deployment.md)
- [Architecture](architecture.md)
