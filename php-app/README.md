# MXA OCR - PHP Web Frontend

This directory contains the PHP web frontend for the MXA OCR application.

## Overview

The PHP application provides:
- Web-based user interface
- Keycloak SSO authentication (OIDC)
- File upload management
- Job status monitoring
- Result viewing and download
- Audit logging

## Requirements

- PHP 8.1 or higher
- Apache 2.4+ with mod_rewrite
- PostgreSQL 14+ client libraries
- Composer (dependency management)

## Directory Structure

```
php-app/
├── public/              # Web-accessible directory (document root)
│   ├── index.php        # Main entry point
│   ├── .htaccess        # Apache rewrite rules
│   └── assets/          # CSS, JavaScript, images
├── src/
│   ├── Config/          # Configuration classes
│   ├── Controllers/     # HTTP request handlers
│   ├── Services/        # Business logic layer
│   ├── Repositories/    # Data access layer
│   ├── Models/          # Data models
│   ├── Middleware/      # Request middleware
│   └── Views/           # HTML templates
├── storage/             # Application storage (not web-accessible)
│   ├── logs/            # Application logs
│   ├── cache/           # Cache files
│   ├── sessions/        # Session files
│   └── uploads/         # Temporary uploads
├── composer.json        # PHP dependencies
├── .env.example         # Environment configuration template
└── README.md            # This file
```

## Installation

### 1. Install Dependencies

```bash
cd php-app
composer install
```

### 2. Configure Environment

```bash
cp .env.example .env
```

Edit `.env` and update these critical values:

```env
# Application
APP_URL=https://ocr.gismartanalytics.com
APP_KEY=<generate-with-openssl-rand-hex-32>

# Database
DB_HOST=192.168.1.66
DB_PASSWORD=<your-secure-password>

# Keycloak
KEYCLOAK_CLIENT_SECRET=<from-keycloak-admin>

# MinIO
MINIO_ACCESS_KEY=<your-minio-access-key>
MINIO_SECRET_KEY=<your-minio-secret-key>
```

### 3. Set Permissions

```bash
chmod 600 .env
chmod 775 storage/logs storage/cache storage/sessions storage/uploads
chown -R www-data:www-data storage/
```

### 4. Configure Apache

Point your Apache virtual host document root to `php-app/public/`:

```apache
DocumentRoot /var/www/mxa-ocr-app/current/php-app/public
```

See `../deploy/apache/mxa-ocr.conf` for complete vhost configuration.

## Development

### Running Locally

For development/testing, you can use PHP's built-in server:

```bash
cd php-app
php -S localhost:8080 -t public
```

Then visit: http://localhost:8080

**Note**: Authentication will not work without proper Keycloak setup.

### Testing

```bash
composer test
```

### Code Analysis

```bash
composer stan
```

## Configuration

### Environment Variables

See `.env.example` for all available configuration options.

Key sections:
- **App**: Application name, URL, debug mode
- **Database**: PostgreSQL connection
- **Keycloak**: SSO configuration
- **Python API**: Backend API connection
- **MinIO**: Object storage
- **Session**: Session management
- **Security**: Keys and tokens
- **Upload**: File upload limits

### Session Management

Sessions are configured for security:
- Secure cookies (HTTPS only)
- HttpOnly cookies
- SameSite=Strict
- 30-minute idle timeout
- Session files stored in `storage/sessions/`

### Logging

Application logs are written to `storage/logs/app.log`.

Log rotation is handled automatically (30-day retention).

## Architecture

### Request Flow

1. Request → Apache
2. `.htaccess` → Rewrite to `index.php`
3. `index.php` → Initialize environment, start session
4. Router → Match path to controller/view
5. Controller → Process request
6. View → Render HTML
7. Response → Client

### Authentication Flow

1. User visits site → Redirect to `/auth/login`
2. Click "Sign in with SSO" → Redirect to Keycloak
3. User authenticates at Keycloak
4. Keycloak → Callback to `/auth/callback` with code
5. Exchange code for tokens
6. Fetch user info from Keycloak
7. Create/update user in local database
8. Store session data
9. Redirect to dashboard

### Database Access

All database access goes through repositories:

```php
$userRepo = new UserRepository();
$user = $userRepo->findById($userId);
```

Never use raw SQL in controllers or views.

### API Communication

Communication with Python backend uses `PythonApiClient`:

```php
$api = new PythonApiClient();
$result = $api->submitJob($jobData);
```

## Security

- ✅ CSRF protection (implement in middleware)
- ✅ SQL injection prevention (PDO prepared statements)
- ✅ XSS prevention (HTML escaping in views)
- ✅ Secure session management
- ✅ Role-based access control
- ✅ Audit logging
- ✅ No hardcoded secrets

## Maintenance

### Clear Cache

```bash
rm -rf storage/cache/*
```

### Clear Sessions

```bash
rm -rf storage/sessions/*
```

### View Logs

```bash
tail -f storage/logs/app.log
```

## Troubleshooting

### "Database connection failed"

- Check database credentials in `.env`
- Verify PostgreSQL is running on 192.168.1.66
- Test connection: `psql -h 192.168.1.66 -U mxa_ocr_user -d mxa_ocr`

### "Failed to obtain access token"

- Verify Keycloak is accessible
- Check client ID and secret in `.env`
- Verify redirect URI matches Keycloak configuration

### "Permission denied" errors

- Check file permissions on `storage/` directories
- Ensure Apache user (www-data) can write to storage

## Related Documentation

- [Main README](../README.md) - Project overview
- [Architecture](../docs/architecture.md) - System architecture
- [Deployment](../docs/deployment.md) - Deployment procedures
- [Authentication](../docs/authentication.md) - SSO integration details

## Support

For issues specific to the PHP frontend, check the troubleshooting section above. For general application issues, see the main project documentation.
