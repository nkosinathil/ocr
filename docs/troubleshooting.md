# MXA OCR - Troubleshooting Guide

## Common Issues and Solutions

This guide covers common issues you may encounter with the MXA OCR application and how to resolve them.

---

## PHP Frontend Issues

### Issue: "Database connection failed"

**Symptoms:**
- Error message when accessing the application
- Cannot load pages

**Possible Causes:**
1. PostgreSQL not running
2. Incorrect database credentials
3. Network connectivity issues
4. Database doesn't exist

**Solutions:**

1. Check if PostgreSQL is running:
```bash
sudo systemctl status postgresql
sudo systemctl start postgresql
```

2. Verify database exists:
```bash
sudo -u postgres psql -l | grep mxa_ocr
```

3. Test connection manually:
```bash
psql -h 192.168.1.66 -U mxa_ocr_user -d mxa_ocr
```

4. Check credentials in `.env`:
```bash
cat /var/www/mxa-ocr-app/current/php-app/.env | grep DB_
```

5. Verify network connectivity:
```bash
ping 192.168.1.66
telnet 192.168.1.66 5432
```

---

### Issue: "Failed to obtain access token"

**Symptoms:**
- Cannot log in
- Redirected back to login page
- Error about Keycloak

**Possible Causes:**
1. Keycloak not accessible
2. Incorrect client ID or secret
3. Redirect URI mismatch
4. Keycloak realm not configured

**Solutions:**

1. Verify Keycloak is accessible:
```bash
curl http://192.168.1.59:8080
```

2. Check Keycloak configuration in `.env`:
```env
KEYCLOAK_URL=http://192.168.1.59:8080
KEYCLOAK_REALM=master
KEYCLOAK_CLIENT_ID=mxa-ocr-web
KEYCLOAK_CLIENT_SECRET=your-secret-here
KEYCLOAK_REDIRECT_URI=https://ocr.gismartanalytics.com/auth/callback
```

3. Verify client exists in Keycloak Admin Console

4. Check redirect URI matches exactly (including trailing slash)

5. Review PHP logs:
```bash
tail -f /var/www/mxa-ocr-app/current/php-app/storage/logs/app.log
tail -f /var/log/apache2/mxa-ocr-error.log
```

---

### Issue: "Permission denied" on storage directories

**Symptoms:**
- Cannot upload files
- Session errors
- Cache errors

**Possible Causes:**
- Incorrect file permissions
- Wrong ownership

**Solutions:**

```bash
cd /var/www/mxa-ocr-app/current/php-app
sudo chown -R www-data:www-data storage/
sudo chmod -R 775 storage/
```

Verify permissions:
```bash
ls -la storage/
# Should show: drwxrwxr-x www-data www-data
```

---

### Issue: Apache 500 Internal Server Error

**Symptoms:**
- Blank page or generic error
- 500 status code

**Solutions:**

1. Enable error display temporarily (in `.env`):
```env
APP_DEBUG=true
```

2. Check Apache error log:
```bash
sudo tail -f /var/log/apache2/mxa-ocr-error.log
```

3. Check PHP error log:
```bash
sudo tail -f /var/log/apache2/error.log
```

4. Verify mod_rewrite is enabled:
```bash
sudo a2enmod rewrite
sudo systemctl restart apache2
```

5. Check .htaccess exists in public directory

---

## Python Backend Issues

### Issue: "Connection refused" when calling Python API

**Symptoms:**
- Jobs not submitting
- Health check fails
- Connection timeout

**Possible Causes:**
1. FastAPI service not running
2. Wrong port or host
3. Firewall blocking connection

**Solutions:**

1. Check if service is running:
```bash
sudo systemctl status mxa-ocr-api
```

2. Start the service:
```bash
sudo systemctl start mxa-ocr-api
```

3. Check if port is listening:
```bash
sudo netstat -tlnp | grep 8100
# or
sudo ss -tlnp | grep 8100
```

4. Test locally on Python server:
```bash
curl http://localhost:8100/api/v1/health
```

5. Test from App server:
```bash
curl http://192.168.1.90:8100/api/v1/health
```

6. Check firewall:
```bash
sudo ufw status
sudo ufw allow 8100/tcp
```

7. View service logs:
```bash
sudo journalctl -u mxa-ocr-api -f
```

---

### Issue: Celery worker not processing jobs

**Symptoms:**
- Jobs stuck in "pending" status
- No processing happening
- Queue backed up

**Possible Causes:**
1. Worker not running
2. Redis not accessible
3. Wrong queue name
4. Worker crashed

**Solutions:**

1. Check worker status:
```bash
sudo systemctl status mxa-ocr-worker
```

2. Start worker:
```bash
sudo systemctl start mxa-ocr-worker
```

3. Check worker logs:
```bash
sudo journalctl -u mxa-ocr-worker -f
```

4. Inspect Celery:
```bash
cd /opt/apps/mxa-ocr/python-backend
source venv/bin/activate
celery -A app.tasks.celery_app inspect active
celery -A app.tasks.celery_app inspect stats
```

5. Check Redis:
```bash
redis-cli ping
# Should return: PONG
```

6. Check queue length:
```bash
redis-cli llen mxa_ocr
```

7. Manually start worker for testing:
```bash
cd /opt/apps/mxa-ocr/python-backend
source venv/bin/activate
celery -A app.tasks.celery_app worker --loglevel=debug -Q mxa_ocr
```

---

### Issue: "Tesseract not found"

**Symptoms:**
- OCR fails with error
- Jobs fail immediately
- "Tesseract not found" in logs

**Solutions:**

1. Install Tesseract:
```bash
sudo apt-get update
sudo apt-get install tesseract-ocr tesseract-ocr-eng
```

2. Verify installation:
```bash
which tesseract
tesseract --version
```

3. Update path in `.env`:
```env
TESSERACT_CMD=/usr/bin/tesseract
```

4. Install additional languages:
```bash
sudo apt-get install tesseract-ocr-afr tesseract-ocr-ara
```

---

### Issue: MinIO connection errors

**Symptoms:**
- Cannot upload/download files
- File not found errors
- Connection timeout

**Solutions:**

1. Check MinIO is running:
```bash
systemctl status minio
# or
ps aux | grep minio
```

2. Test MinIO connection:
```bash
mc config host add myminio http://192.168.1.90:9000 ACCESS_KEY SECRET_KEY
mc ls myminio/
```

3. Verify buckets exist:
```bash
mc ls myminio/ | grep mxa-ocr
```

4. Create buckets if missing:
```bash
mc mb myminio/mxa-ocr-input
mc mb myminio/mxa-ocr-output
```

5. Check credentials in `.env`:
```env
MINIO_ENDPOINT=192.168.1.90:9000
MINIO_ACCESS_KEY=your-access-key
MINIO_SECRET_KEY=your-secret-key
```

6. Test connectivity:
```bash
curl http://192.168.1.90:9000/minio/health/live
```

---

## Database Issues

### Issue: "Too many connections"

**Symptoms:**
- Database connection errors
- "Too many connections" error

**Solutions:**

1. Check current connections:
```bash
sudo -u postgres psql -c "SELECT count(*) FROM pg_stat_activity;"
```

2. Increase max_connections in PostgreSQL:
```bash
sudo nano /etc/postgresql/14/main/postgresql.conf
# Set: max_connections = 200
sudo systemctl restart postgresql
```

3. Reduce connection pool size in applications:
```env
# PHP .env
DB_POOL_SIZE=20

# Python .env
DB_POOL_SIZE=20
```

---

### Issue: Slow database queries

**Symptoms:**
- Application slow to load
- Timeouts
- High CPU on database server

**Solutions:**

1. Check slow queries:
```bash
sudo -u postgres psql mxa_ocr
SELECT * FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;
```

2. Analyze tables:
```bash
sudo -u postgres psql mxa_ocr -c "VACUUM ANALYZE;"
```

3. Check missing indexes:
```bash
sudo -u postgres psql mxa_ocr -f database/migrations/002_add_indexes.sql
```

4. Monitor queries:
```bash
sudo -u postgres psql mxa_ocr
\x
SELECT * FROM pg_stat_activity WHERE state = 'active';
```

---

## Performance Issues

### Issue: High memory usage

**Symptoms:**
- System running out of memory
- OOM killer terminating processes

**Solutions:**

1. Check memory usage:
```bash
free -h
top
htop
```

2. Reduce Celery concurrency:
```env
CELERY_WORKER_CONCURRENCY=2
```

3. Restart services:
```bash
sudo systemctl restart mxa-ocr-worker
sudo systemctl restart mxa-ocr-api
```

4. Add swap if needed:
```bash
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

---

### Issue: Slow OCR processing

**Symptoms:**
- Jobs taking too long
- Timeouts

**Solutions:**

1. Reduce DPI (lower quality, faster):
```env
OCR_DPI=150
```

2. Increase worker concurrency:
```env
CELERY_WORKER_CONCURRENCY=8
```

3. Add more workers:
```bash
# On additional servers
sudo systemctl start mxa-ocr-worker
```

4. Optimize Tesseract:
```env
# Use faster OCR engine mode
OCR_ENGINE_MODE=1
```

---

## Log Files

### Where to find logs

**PHP Application:**
- Application log: `/var/www/mxa-ocr-app/current/php-app/storage/logs/app.log`
- Apache error log: `/var/log/apache2/mxa-ocr-error.log`
- Apache access log: `/var/log/apache2/mxa-ocr-access.log`

**Python Backend:**
- FastAPI: `sudo journalctl -u mxa-ocr-api`
- Celery: `sudo journalctl -u mxa-ocr-worker`
- Application log: `/var/log/mxa-ocr/backend.log`

**Database:**
- PostgreSQL: `/var/log/postgresql/postgresql-14-main.log`

**System:**
- System log: `sudo journalctl -xe`
- Kernel log: `dmesg`

### Viewing logs in real-time

```bash
# PHP
tail -f /var/www/mxa-ocr-app/current/php-app/storage/logs/app.log

# Python API
sudo journalctl -u mxa-ocr-api -f

# Celery Worker
sudo journalctl -u mxa-ocr-worker -f

# Apache
sudo tail -f /var/log/apache2/mxa-ocr-error.log
```

---

## Getting Help

If you cannot resolve the issue:

1. **Collect information:**
   - Error messages from logs
   - Steps to reproduce
   - System configuration
   - Recent changes

2. **Check documentation:**
   - [Architecture](architecture.md)
   - [Deployment](deployment.md)
   - [API Reference](api.md)

3. **Contact support:**
   - Create GitHub issue with details
   - Include relevant log excerpts
   - Describe what you've already tried

---

## Preventive Measures

### Regular Maintenance

```bash
# Weekly
- Check disk space: df -h
- Review logs for errors
- Check service status

# Monthly
- Update packages: sudo apt-get update && sudo apt-get upgrade
- Vacuum database: VACUUM ANALYZE
- Clean old files: cleanup_old_jobs()
- Review performance metrics

# Quarterly
- Review and update documentation
- Security audit
- Backup testing
- Capacity planning
```

### Monitoring

Set up monitoring for:
- Service uptime
- Disk space
- Memory usage
- CPU usage
- Queue depth
- Processing times
- Error rates

### Backups

Regular backups of:
- PostgreSQL database
- MinIO buckets
- Configuration files (.env)
- Application code

Test restores regularly!
