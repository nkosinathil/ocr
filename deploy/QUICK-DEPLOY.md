# MXA OCR - Quick Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying MXA OCR to production servers.

## Prerequisites

- Access to three servers:
  - **App Server** (192.168.1.66) - PHP, PostgreSQL, Apache
  - **Python Server** (192.168.1.90) - Python, Redis, MinIO
  - **SSO Server** (192.168.1.59) - Keycloak
- SSH access to all servers (with key-based authentication recommended)
- Root or sudo privileges
- Git repository access

## Deployment Scripts

All deployment scripts are located in `deploy/scripts/`:

| Script | Purpose |
|--------|---------|
| `pre-deploy-check.sh` | Verify prerequisites before deployment |
| `deploy-master.sh` | Master orchestration script for full deployment |
| `setup-database.sh` | Setup PostgreSQL database |
| `setup-php.sh` | Deploy PHP application |
| `setup-python.sh` | Deploy Python backend |
| `setup-minio.sh` | Configure MinIO storage |
| `post-deploy-validate.sh` | Validate deployment after completion |
| `rollback.sh` | Rollback to previous deployment |

## Quick Start Deployment

### Step 1: Pre-Deployment Check

From your local machine or CI/CD server:

```bash
cd deploy/scripts
bash pre-deploy-check.sh
```

This will verify:
- Network connectivity to all servers
- SSH access
- Required software installed
- Services running
- Disk space available

**Fix any issues before proceeding!**

### Step 2: Run Master Deployment

```bash
cd deploy/scripts
bash deploy-master.sh
```

The master script will:
1. Check SSH connections
2. Upload code to both servers
3. Setup database on App Server
4. Deploy PHP application
5. Deploy Python backend
6. Setup MinIO storage
7. Start all services
8. Run basic validation

**Important:** The script will pause and ask you to configure `.env` files. Have your credentials ready!

### Step 3: Configure Environment Files

When prompted, update the `.env` files on both servers:

**On App Server (192.168.1.66):**
```bash
ssh root@192.168.1.66
nano /var/www/mxa-ocr-app/current/php-app/.env
```

Update these critical values:
- `KEYCLOAK_CLIENT_SECRET` - Get from Keycloak
- `APP_KEY` - Generate with: `openssl rand -hex 32`
- `DB_PASSWORD` - Your PostgreSQL password
- `MINIO_ACCESS_KEY` and `MINIO_SECRET_KEY` - Must match Python `.env` values

**On Python Server (192.168.1.90):**
```bash
ssh root@192.168.1.90
nano /opt/apps/mxa-ocr/python-backend/.env
```

Update these critical values:
- `DB_PASSWORD` - Same as PHP
- `MINIO_ACCESS_KEY` and `MINIO_SECRET_KEY` - Source of truth for MinIO app credentials
- `REDIS_PASSWORD` - If Redis has authentication

> `deploy/scripts/setup-minio.sh` now auto-generates MinIO credentials if placeholders are detected, writes them to `/opt/apps/mxa-ocr/python-backend/.env`, and reuses them on subsequent runs. Keep PHP `.env` MinIO credentials aligned to these Python `.env` values.

### Step 4: Configure Keycloak

1. Login to Keycloak Admin Console:
   ```
   http://192.168.1.59:8080/admin
   ```

2. Select your realm (or create a new one)

3. Create a new client:
   - **Client ID:** `mxa-ocr-web`
   - **Client Protocol:** `openid-connect`
   - **Access Type:** `confidential`
   - **Valid Redirect URIs:** `https://ocr.gismartanalytics.com/auth/callback`
   - **Web Origins:** `https://ocr.gismartanalytics.com`

4. Go to the **Credentials** tab and copy the **Client Secret**

5. Update the PHP `.env` file with this secret:
   ```bash
   ssh root@192.168.1.66
   nano /var/www/mxa-ocr-app/current/php-app/.env
   # Update: KEYCLOAK_CLIENT_SECRET=your-secret-here
   ```

6. Create roles (optional but recommended):
   - `ocr_admin` - Full access
   - `ocr_user` - Regular user access
   - `ocr_viewer` - Read-only access

7. Assign roles to users

8. Restart Apache:
   ```bash
   ssh root@192.168.1.66
   systemctl reload apache2
   ```

### Step 5: Post-Deployment Validation

Run the validation script:

```bash
cd deploy/scripts
bash post-deploy-validate.sh
```

This checks:
- All services are running
- Database is accessible
- API endpoints respond
- Configuration files exist
- No critical errors in logs

### Step 6: Test the Application

1. **Test Authentication:**
   - Visit: `https://ocr.gismartanalytics.com`
   - Click Login
   - Should redirect to Keycloak
   - Login with a test user
   - Should redirect back to application

2. **Test OCR Processing:**
   - Upload a test PDF or image
   - Submit for processing
   - Check job status
   - Verify results are displayed

3. **Monitor Logs:**
   ```bash
   # Python API logs
   ssh root@192.168.1.90
   journalctl -u mxa-ocr-api -f
   
   # Celery worker logs
   journalctl -u mxa-ocr-worker -f
   
   # Apache logs
   ssh root@192.168.1.66
   tail -f /var/log/apache2/mxa-ocr-error.log
   ```

## Manual Deployment (Alternative)

If you prefer manual deployment or the automated script fails:

### On App Server (192.168.1.66)

```bash
# 1. Setup database
cd deploy/scripts
sudo -u postgres bash setup-database.sh

# 2. Deploy PHP app
sudo bash setup-php.sh

# 3. Configure .env
cd /var/www/mxa-ocr-app/current/php-app
sudo nano .env
# Update all credentials

# 4. Restart Apache
sudo systemctl reload apache2
```

### On Python Server (192.168.1.90)

```bash
# 1. Deploy Python backend
cd deploy/scripts
sudo bash setup-python.sh

# 2. Setup MinIO
sudo bash setup-minio.sh

# 3. Configure .env
cd /opt/apps/mxa-ocr/python-backend
sudo nano .env
# Update all credentials

# 4. Start services
sudo systemctl start mxa-ocr-api
sudo systemctl start mxa-ocr-worker
sudo systemctl enable mxa-ocr-api
sudo systemctl enable mxa-ocr-worker
```

## Troubleshooting

### Services Not Starting

```bash
# Check service status
systemctl status mxa-ocr-api
systemctl status mxa-ocr-worker

# View detailed logs
journalctl -u mxa-ocr-api -n 100
journalctl -u mxa-ocr-worker -n 100
```

### Database Connection Issues

```bash
# Test database connection
ssh root@192.168.1.66
sudo -u postgres psql -d mxa_ocr

# Check if user can connect
psql -U mxa_ocr_user -d mxa_ocr -h localhost
```

### API Not Responding

```bash
# Check if API is listening
ssh root@192.168.1.90
netstat -tlnp | grep 8100

# Test API directly
curl http://localhost:8100/api/v1/health
```

### MinIO Issues

```bash
# Check MinIO status
ssh root@192.168.1.90
systemctl status minio

# Test MinIO connection
mc admin info mxaocr
```

## Rollback Procedure

If deployment fails or causes issues:

```bash
cd deploy/scripts
bash rollback.sh
```

Follow the prompts to select a previous release.

## Updating the Application

To deploy updates:

```bash
# 1. Pull latest code
cd /path/to/local/repo
git pull

# 2. Run deployment again
cd deploy/scripts
bash deploy-master.sh

# The script will create a new release and update the symlink
```

## Security Checklist

Before going live:

- [ ] Change all default passwords
- [ ] Generate new APP_KEY for PHP
- [ ] Configure SSL certificates (Let's Encrypt recommended)
- [ ] Set `APP_DEBUG=false` in both `.env` files
- [ ] Restrict database access to application servers only
- [ ] Configure firewall rules (allow only necessary ports)
- [ ] Enable fail2ban or similar intrusion detection
- [ ] Set up automated backups
- [ ] Configure log rotation
- [ ] Test disaster recovery procedures
- [ ] Set up monitoring and alerting
- [ ] Review and update Keycloak security settings

## Monitoring

### Health Checks

Set up automated health checks for:

```bash
# Python API
curl http://192.168.1.90:8100/api/v1/health

# PHP Application
curl https://ocr.gismartanalytics.com/

# Database
psql -U mxa_ocr_user -d mxa_ocr -c "SELECT 1"

# Redis
redis-cli ping

# MinIO
mc admin info mxaocr
```

### Log Locations

| Component | Log Location |
|-----------|-------------|
| Python API | `journalctl -u mxa-ocr-api` |
| Celery Worker | `journalctl -u mxa-ocr-worker` |
| Apache Access | `/var/log/apache2/mxa-ocr-access.log` |
| Apache Error | `/var/log/apache2/mxa-ocr-error.log` |
| PostgreSQL | `/var/log/postgresql/postgresql-*.log` |
| Redis | `/var/log/redis/redis-server.log` |

## Support

For deployment issues:

1. Check the logs on the relevant server
2. Run `post-deploy-validate.sh` to identify issues
3. Review the [Troubleshooting Guide](../../docs/troubleshooting.md)
4. Check service status: `systemctl status <service>`
5. Verify network connectivity between servers
6. Ensure credentials in `.env` files are correct

## Maintenance

### Regular Tasks

- **Daily:** Monitor logs for errors
- **Weekly:** Check disk space and resource usage
- **Monthly:** Review and rotate logs, backup database
- **Quarterly:** Update dependencies, review security

### Service Commands

```bash
# Restart services
sudo systemctl restart mxa-ocr-api
sudo systemctl restart mxa-ocr-worker
sudo systemctl reload apache2

# View logs
journalctl -u mxa-ocr-api -f
journalctl -u mxa-ocr-worker -f

# Check status
systemctl status mxa-ocr-api
systemctl status mxa-ocr-worker
```

---

**Last Updated:** 2026-04-10
