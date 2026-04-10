# MXA OCR - Deployment Scripts

This directory contains automated deployment scripts for MXA OCR.

## Quick Start

### Option 1: Full Production Deployment (3 Servers)

For deploying to the production infrastructure (App Server, Python Server, SSO Server):

```bash
# 1. Run pre-deployment checks
bash pre-deploy-check.sh

# 2. Deploy to all servers
bash deploy-master.sh

# 3. Validate deployment
bash post-deploy-validate.sh
```

### Option 2: Single Server Deployment (Testing/Development)

For deploying everything on one server (local testing):

```bash
sudo bash deploy-single-server.sh
```

## Scripts Overview

### Orchestration Scripts

| Script | Description | When to Use |
|--------|-------------|-------------|
| **deploy-master.sh** | Full multi-server deployment | Production deployment to 3 servers |
| **deploy-single-server.sh** | Single server deployment | Local testing/development |
| **pre-deploy-check.sh** | Pre-deployment validation | Before any deployment |
| **post-deploy-validate.sh** | Post-deployment validation | After deployment to verify |
| **rollback.sh** | Rollback to previous version | If deployment fails |

### Component Setup Scripts

| Script | Description | Server |
|--------|-------------|--------|
| **setup-database.sh** | PostgreSQL setup | App Server (192.168.1.66) |
| **setup-php.sh** | PHP application deployment | App Server (192.168.1.66) |
| **setup-python.sh** | Python backend deployment | Python Server (192.168.1.90) |
| **setup-minio.sh** | MinIO storage setup | Python Server (192.168.1.90) |

## Detailed Usage

### Pre-Deployment Check

Verifies all prerequisites before deployment:

```bash
bash pre-deploy-check.sh
```

**Checks:**
- Network connectivity to all servers
- SSH access
- Required software installed (PHP, Python, PostgreSQL, etc.)
- Services running (Apache, Redis, etc.)
- Disk space availability
- Port accessibility

**Exit Codes:**
- `0` - All checks passed
- `1` - One or more checks failed

### Master Deployment

Orchestrates full deployment across all servers:

```bash
# With default values
bash deploy-master.sh

# With custom SSH user
SSH_USER=admin bash deploy-master.sh

# With custom branch
BRANCH=develop bash deploy-master.sh
```

**Environment Variables:**
- `APP_SERVER` - App server IP (default: 192.168.1.66)
- `PYTHON_SERVER` - Python server IP (default: 192.168.1.90)
- `SSO_SERVER` - SSO server IP (default: 192.168.1.59)
- `SSH_USER` - SSH username (default: root)
- `REPO_URL` - Git repository URL
- `BRANCH` - Git branch to deploy (default: main)

**What it does:**
1. Verifies SSH connections
2. Creates deployment archive
3. Uploads code to servers
4. Runs database setup
5. Deploys PHP application
6. Deploys Python backend
7. Configures MinIO
8. Starts all services
9. Runs basic validation
10. Provides next steps

**Interactive Prompts:**
- Confirms deployment
- Pauses for `.env` configuration
- Shows completion summary

### Individual Component Setup

Run these scripts directly on the target servers:

**Database Setup (on App Server):**
```bash
sudo -u postgres bash setup-database.sh
```

**PHP Application (on App Server):**
```bash
sudo bash setup-php.sh
```

**Python Backend (on Python Server):**
```bash
sudo bash setup-python.sh
```

**MinIO Storage (on Python Server):**
```bash
sudo bash setup-minio.sh
```

### Post-Deployment Validation

Comprehensive testing after deployment:

```bash
bash post-deploy-validate.sh
```

**Tests:**
- Service status (PostgreSQL, Apache, FastAPI, Celery, Redis)
- Database existence and tables
- API endpoints (health, root)
- File system structure
- Configuration files
- MinIO buckets
- Log analysis
- Resource usage (disk, memory)
- Security settings (DEBUG mode)

**Exit Codes:**
- `0` - All tests passed
- `1` - One or more tests failed

### Rollback

Revert to a previous deployment:

```bash
bash rollback.sh
```

**Interactive Process:**
1. Lists available releases
2. Shows current release
3. Prompts for release to rollback to
4. Creates backup of current state
5. Stops services
6. Updates symlinks
7. Restarts services
8. Verifies rollback

**Note:** This only rolls back the PHP application. Python backend rollback requires manual intervention.

## Configuration

### SSH Setup

For passwordless deployment, set up SSH key authentication:

```bash
# Generate SSH key (if you don't have one)
ssh-keygen -t rsa -b 4096

# Copy to servers
ssh-copy-id root@192.168.1.66
ssh-copy-id root@192.168.1.90
ssh-copy-id root@192.168.1.59

# Test connection
ssh root@192.168.1.66 "echo 'Connection successful'"
```

### Environment Variables

Set these before running deployment scripts:

```bash
export APP_SERVER="192.168.1.66"
export PYTHON_SERVER="192.168.1.90"
export SSO_SERVER="192.168.1.59"
export SSH_USER="root"
export REPO_URL="https://github.com/nkosinathil/ocr.git"
export BRANCH="main"
```

Or create a `.env` file:

```bash
# deploy/.env
APP_SERVER=192.168.1.66
PYTHON_SERVER=192.168.1.90
SSO_SERVER=192.168.1.59
SSH_USER=root
REPO_URL=https://github.com/nkosinathil/ocr.git
BRANCH=main
```

Then source it:
```bash
source deploy/.env
bash deploy/scripts/deploy-master.sh
```

## Troubleshooting

### SSH Connection Failed

```bash
# Check if server is reachable
ping 192.168.1.66

# Test SSH connection
ssh -v root@192.168.1.66

# Check SSH key permissions
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
```

### Service Start Failed

```bash
# Check service logs
ssh root@192.168.1.90
journalctl -u mxa-ocr-api -n 100 --no-pager

# Check service status
systemctl status mxa-ocr-api

# Try manual start
systemctl start mxa-ocr-api
```

### Database Connection Failed

```bash
# Test database connection
ssh root@192.168.1.66
sudo -u postgres psql -d mxa_ocr

# Check if database exists
sudo -u postgres psql -l | grep mxa_ocr

# Check PostgreSQL logs
tail -f /var/log/postgresql/postgresql-*.log
```

### Permission Denied Errors

```bash
# Fix PHP application permissions
ssh root@192.168.1.66
chown -R www-data:www-data /var/www/mxa-ocr-app
chmod -R 775 /var/www/mxa-ocr-app/current/php-app/storage

# Fix Python application permissions
ssh root@192.168.1.90
chown -R mxa-ocr:mxa-ocr /opt/apps/mxa-ocr
```

## Best Practices

1. **Always run pre-deployment checks first**
   ```bash
   bash pre-deploy-check.sh
   ```

2. **Test in development first**
   ```bash
   bash deploy-single-server.sh  # On a test server
   ```

3. **Backup before deployment**
   ```bash
   # Backup database
   ssh root@192.168.1.66
   sudo -u postgres pg_dump mxa_ocr > mxa_ocr_backup_$(date +%Y%m%d).sql
   ```

4. **Monitor during deployment**
   ```bash
   # In separate terminals
   ssh root@192.168.1.90
   journalctl -u mxa-ocr-api -f
   ```

5. **Validate after deployment**
   ```bash
   bash post-deploy-validate.sh
   ```

6. **Keep rollback ready**
   - Know how to rollback
   - Have backup of critical data
   - Test rollback procedure in advance

## CI/CD Integration

These scripts can be integrated into CI/CD pipelines:

### GitHub Actions Example

```yaml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup SSH
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.SSH_PRIVATE_KEY }}" > ~/.ssh/id_rsa
          chmod 600 ~/.ssh/id_rsa
      
      - name: Pre-deployment Check
        run: bash deploy/scripts/pre-deploy-check.sh
      
      - name: Deploy
        run: bash deploy/scripts/deploy-master.sh
      
      - name: Validate
        run: bash deploy/scripts/post-deploy-validate.sh
```

### GitLab CI Example

```yaml
deploy:
  stage: deploy
  only:
    - main
  script:
    - bash deploy/scripts/pre-deploy-check.sh
    - bash deploy/scripts/deploy-master.sh
    - bash deploy/scripts/post-deploy-validate.sh
  when: manual
```

## Security Notes

1. **Never commit `.env` files** - They contain sensitive credentials
2. **Use SSH keys** - Avoid password authentication
3. **Limit SSH access** - Only allow deployment from specific IPs
4. **Rotate credentials** - Change passwords regularly
5. **Monitor deployments** - Log all deployment activities
6. **Use least privilege** - Create deployment user with minimal permissions

## Support

For issues with deployment scripts:

1. Check the logs for detailed error messages
2. Run `pre-deploy-check.sh` to identify issues
3. Verify network connectivity and SSH access
4. Check service status on target servers
5. Review the [Troubleshooting Guide](../../docs/troubleshooting.md)

## Maintenance

### Updating Scripts

When modifying deployment scripts:

1. Test changes on development server first
2. Document changes in this README
3. Update version comments in scripts
4. Test rollback procedure still works
5. Commit changes with descriptive message

### Script Versioning

All scripts include version information in comments. Update when making changes:

```bash
# Version: 1.1.0
# Last Updated: 2026-04-10
```

---

**Last Updated:** 2026-04-10  
**Version:** 1.0.0
