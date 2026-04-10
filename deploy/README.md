# MXA OCR - Deployment Configuration

This directory contains all deployment-related configuration and scripts for the MXA OCR application.

## Contents

- `apache/` - Apache virtual host configuration
- `systemd/` - Systemd service definitions
- `scripts/` - Deployment automation scripts

## Quick Deployment

### Prerequisites

Ensure you have access to:
- App Server (192.168.1.66) - PHP, PostgreSQL, Apache
- Python Server (192.168.1.90) - Python, Redis, MinIO
- SSO Server (192.168.1.59) - Keycloak

### Step 1: Database Setup

On the **App Server (192.168.1.66)**:

```bash
cd deploy/scripts
sudo -u postgres ./setup-database.sh
```

This creates:
- Database: `mxa_ocr`
- User: `mxa_ocr_user`
- Schema and tables

### Step 2: PHP Application Setup

On the **App Server (192.168.1.66)**:

```bash
cd deploy/scripts
sudo ./setup-php.sh
```

This:
- Creates `/var/www/mxa-ocr-app/current/php-app`
- Installs Composer dependencies
- Configures Apache vhost
- Sets file permissions

**Important**: Update `/var/www/mxa-ocr-app/current/php-app/.env` with actual credentials!

### Step 3: Python Backend Setup

On the **Python Server (192.168.1.90)**:

```bash
cd deploy/scripts
sudo ./setup-python.sh
```

This:
- Creates `/opt/apps/mxa-ocr` directory
- Creates `mxa-ocr` system user
- Installs system dependencies (Tesseract, etc.)
- Sets up Python virtual environment
- Installs Python packages
- Configures systemd services

**Important**: Update `/opt/apps/mxa-ocr/python-backend/.env` with actual credentials!

### Step 4: Start Services

On **Python Server**:

```bash
sudo systemctl start mxa-ocr-api
sudo systemctl start mxa-ocr-worker
sudo systemctl status mxa-ocr-api
sudo systemctl status mxa-ocr-worker
```

On **App Server**:

```bash
sudo systemctl reload apache2
sudo systemctl status apache2
```

### Step 5: Configure Keycloak

On the **SSO Server (192.168.1.59)**:

1. Log in to Keycloak Admin Console
2. Select your realm (or create new)
3. Create new client:
   - Client ID: `mxa-ocr-web`
   - Client Protocol: `openid-connect`
   - Access Type: `confidential`
   - Valid Redirect URIs: `https://ocr.gismartanalytics.com/auth/callback`
   - Web Origins: `https://ocr.gismartanalytics.com`
4. Note the Client Secret
5. Create roles: `ocr_admin`, `ocr_user`, `ocr_viewer`
6. Assign roles to users

Update PHP `.env` with the client secret:
```env
KEYCLOAK_CLIENT_SECRET=your-secret-from-keycloak
```

### Step 6: Configure MinIO

On the **Python Server (or wherever MinIO is running)**:

```bash
# Create buckets
mc mb myminio/mxa-ocr-input
mc mb myminio/mxa-ocr-output

# Set policy (adjust as needed)
mc policy set download myminio/mxa-ocr-output
```

Update `.env` files with MinIO credentials.

### Step 7: Test Deployment

```bash
# Test Python API
curl http://192.168.1.90:8100/api/v1/health

# Test PHP application
curl https://ocr.gismartanalytics.com/api/health

# Test full authentication flow
# Visit https://ocr.gismartanalytics.com in browser
```

## Manual Deployment

If you prefer manual deployment, follow these steps:

### Database (PostgreSQL on 192.168.1.66)

```bash
sudo -u postgres psql
CREATE USER mxa_ocr_user WITH PASSWORD 'your_password';
CREATE DATABASE mxa_ocr OWNER mxa_ocr_user;
GRANT ALL PRIVILEGES ON DATABASE mxa_ocr TO mxa_ocr_user;
\c mxa_ocr
\i /path/to/database/schema.sql
```

### PHP Application (Apache on 192.168.1.66)

```bash
# Create directories
sudo mkdir -p /var/www/mxa-ocr-app/current

# Clone repository
cd /var/www/mxa-ocr-app/current
sudo git clone <repo-url> .

# Install dependencies
cd php-app
sudo composer install --no-dev

# Configure
sudo cp .env.example .env
sudo nano .env  # Update values

# Set permissions
sudo chown -R www-data:www-data /var/www/mxa-ocr-app
sudo chmod -R 775 php-app/storage

# Configure Apache
sudo cp deploy/apache/mxa-ocr.conf /etc/apache2/sites-available/
sudo a2ensite mxa-ocr
sudo a2enmod rewrite ssl headers
sudo systemctl reload apache2
```

### Python Backend (on 192.168.1.90)

```bash
# Create user
sudo useradd -r -m -d /opt/apps/mxa-ocr mxa-ocr

# Create directories
sudo mkdir -p /opt/apps/mxa-ocr
sudo mkdir -p /var/log/mxa-ocr
sudo mkdir -p /tmp/mxa-ocr

# Clone repository
cd /opt/apps/mxa-ocr
sudo git clone <repo-url> .

# Install system dependencies
sudo apt-get install -y python3.10 python3.10-venv tesseract-ocr poppler-utils

# Setup virtual environment
cd python-backend
sudo -u mxa-ocr python3 -m venv venv
sudo -u mxa-ocr venv/bin/pip install -r requirements.txt

# Configure
sudo -u mxa-ocr cp .env.example .env
sudo nano .env  # Update values

# Install services
sudo cp deploy/systemd/mxa-ocr-api.service /etc/systemd/system/
sudo cp deploy/systemd/mxa-ocr-worker.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable mxa-ocr-api mxa-ocr-worker
sudo systemctl start mxa-ocr-api mxa-ocr-worker
```

## Maintenance

### Restart Services

```bash
# Python API
sudo systemctl restart mxa-ocr-api

# Celery Worker
sudo systemctl restart mxa-ocr-worker

# Apache
sudo systemctl reload apache2
```

### View Logs

```bash
# Python API logs
sudo journalctl -u mxa-ocr-api -f

# Celery worker logs
sudo journalctl -u mxa-ocr-worker -f

# Apache logs
sudo tail -f /var/log/apache2/mxa-ocr-error.log
sudo tail -f /var/log/apache2/mxa-ocr-access.log

# Application logs
sudo tail -f /var/log/mxa-ocr/backend.log
```

### Update Application

```bash
# PHP application
cd /var/www/mxa-ocr-app/current
sudo git pull
cd php-app
sudo composer install --no-dev
sudo systemctl reload apache2

# Python backend
cd /opt/apps/mxa-ocr
sudo git pull
cd python-backend
sudo -u mxa-ocr venv/bin/pip install -r requirements.txt
sudo systemctl restart mxa-ocr-api
sudo systemctl restart mxa-ocr-worker
```

## Troubleshooting

See [../docs/troubleshooting.md](../docs/troubleshooting.md) for common issues and solutions.

## Security Checklist

Before going to production:

- [ ] Change all default passwords
- [ ] Generate new APP_KEY for PHP
- [ ] Configure SSL certificates
- [ ] Set APP_DEBUG=false
- [ ] Restrict database access to application servers only
- [ ] Configure firewall rules
- [ ] Enable fail2ban or similar
- [ ] Set up backup procedures
- [ ] Configure log rotation
- [ ] Test disaster recovery procedures

## Support

For deployment issues:
1. Check service status: `systemctl status <service-name>`
2. Check logs: `journalctl -u <service-name> -n 100`
3. Verify network connectivity between servers
4. Verify credentials in .env files
5. Check file permissions
