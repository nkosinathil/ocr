# MXA OCR - Deployment Guide

## Overview

This guide covers deploying the MXA OCR application to production.

## Prerequisites

- App Server (192.168.1.66) with Apache, PHP 8.1+, PostgreSQL 14+
- Python Server (192.168.1.90) with Python 3.10+, Redis, MinIO
- SSO Server (192.168.1.59) with Keycloak

## Quick Deployment

See [deploy/README.md](../deploy/README.md) for detailed deployment instructions.

### Summary Steps

1. Setup database: `./deploy/scripts/setup-database.sh`
2. Setup PHP: `./deploy/scripts/setup-php.sh`
3. Setup Python: `./deploy/scripts/setup-python.sh`
4. Configure Keycloak client
5. Configure MinIO buckets
6. Start services
7. Test deployment

## Manual Deployment

See deployment scripts for manual step-by-step instructions.

## Post-Deployment

- Configure SSL certificates
- Set up monitoring
- Configure backups
- Test all functionality
- Update DNS records

## Related Documentation
- [Architecture](architecture.md)
- [Configuration](configuration.md)
- [Troubleshooting](troubleshooting.md)
