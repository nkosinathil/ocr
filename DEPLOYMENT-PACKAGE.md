# MXA OCR - Deployment Package

## Executive Summary

Your MXA OCR application now has **complete production-ready deployment scripts** that automate the entire deployment process to your 3-server infrastructure.

## 🚀 Quick Start - Deploy to Production

### Option 1: Non-Root Deployment (Recommended - Most Secure)

**Use this if you have SSH access with your own username (not root) and different usernames per server.**

```bash
cd deploy/scripts

# Interactive - prompts for usernames
bash deploy-quick.sh

# OR with environment variables
SSH_USER_APP=john SSH_USER_PYTHON=jane SSH_USER_SSO=admin bash deploy-nonroot.sh
```

📖 **Full Guide:** See [NON-ROOT-DEPLOYMENT.md](NON-ROOT-DEPLOYMENT.md)  
📋 **Quick Reference:** See [NON-ROOT-QUICK-REF.txt](NON-ROOT-QUICK-REF.txt)

### Option 2: Root User Deployment (Traditional)

From your local machine or CI/CD server with root SSH access:

```bash
cd deploy/scripts

# Step 1: Verify prerequisites
bash pre-deploy-check.sh

# Step 2: Deploy to all servers
bash deploy-master.sh

# Step 3: Validate deployment
bash post-deploy-validate.sh
```

### Option 3: Single Server Deployment (Testing/Development)

For testing on a single server:

```bash
cd deploy/scripts
sudo bash deploy-single-server.sh
```

## 📦 What's Included

### 1. Deployment Scripts (12+ scripts)

| Script | Purpose |
|--------|---------|
| **deploy-nonroot.sh** | 🆕 Non-root deployment with custom SSH users per server |
| **deploy-quick.sh** | 🆕 Interactive quick deployment (prompts for usernames) |
| **deploy-config.sh** | 🆕 Configuration template for reusable deployments |
| **deploy-master.sh** | Main orchestration - deploys to all 3 servers (root user) |
| **pre-deploy-check.sh** | Pre-flight validation of all prerequisites |
| **post-deploy-validate.sh** | Post-deployment health checks and validation |
| **setup-database.sh** | PostgreSQL database setup on App Server |
| **setup-php.sh** | PHP application deployment on App Server |
| **setup-python.sh** | Python backend deployment on Python Server |
| **setup-minio.sh** | MinIO object storage configuration |
| **rollback.sh** | Rollback to previous deployment |
| **deploy-single-server.sh** | Single-server deployment for testing |

### 2. Documentation

- **`deploy/NON-ROOT-DEPLOYMENT.md`** 🆕 Complete guide for non-root SSH deployments
- **`deploy/NON-ROOT-QUICK-REF.txt`** 🆕 Quick reference card for command-line usage
- **`deploy/QUICK-DEPLOY.md`** - Step-by-step deployment guide
- **`deploy/scripts/README.md`** - Detailed script documentation
- **`deploy/README.md`** - Original deployment overview

## 🎯 Target Infrastructure

Your scripts are configured for this 3-server architecture:

```
┌─────────────────────────────────────────────────────────┐
│              App Server (192.168.1.66)                  │
│  - PHP 8.1 + Apache                                     │
│  - PostgreSQL 14                                        │
│  - PHP Web Application                                  │
└─────────────────────────────────────────────────────────┘
                           ▲
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│           Python Server (192.168.1.90)                  │
│  - Python 3.10 + FastAPI                                │
│  - Celery Workers                                       │
│  - Redis (task queue)                                   │
│  - MinIO (object storage)                               │
│  - Tesseract OCR                                        │
└─────────────────────────────────────────────────────────┘
                           ▲
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│              SSO Server (192.168.1.59)                  │
│  - Keycloak 20+                                         │
│  - OIDC Authentication                                  │
└─────────────────────────────────────────────────────────┘
```

## 📋 Deployment Checklist

### Before Deployment

- [ ] Ensure you have SSH access to all 3 servers
- [ ] Set up SSH key authentication (passwordless login)
  - For non-root: See [NON-ROOT-DEPLOYMENT.md](deploy/NON-ROOT-DEPLOYMENT.md)
  - For root: Use `ssh-copy-id root@server` or manual key installation
- [ ] Verify sudo access (for non-root deployments)
- [ ] Have database passwords ready
- [ ] Have MinIO credentials ready
- [ ] Keycloak is running on SSO server
- [ ] All servers have internet access

### During Deployment

The `deploy-master.sh` script will:
1. ✅ Verify SSH connections to all servers
2. ✅ Create deployment archive from your repo
3. ✅ Upload code to both App and Python servers
4. ✅ Setup PostgreSQL database with schema
5. ✅ Deploy PHP application with dependencies
6. ✅ Deploy Python backend with virtualenv
7. ✅ Configure MinIO buckets
8. ✅ Start all systemd services
9. ✅ Run basic health checks

**Note:** The script will pause twice:
- After PHP deployment - to let you configure PHP `.env`
- After Python deployment - to let you configure Python `.env`

### After Deployment

- [ ] Configure `.env` files with actual credentials
- [ ] Configure Keycloak client and get secret
- [ ] Update PHP `.env` with Keycloak client secret
- [ ] Test authentication flow
- [ ] Upload a test document
- [ ] Verify OCR processing works
- [ ] Set up SSL certificates
- [ ] Configure monitoring
- [ ] Set up automated backups

## 🔧 Configuration Files to Update

### PHP Application (.env)

Location: `/var/www/mxa-ocr-app/current/php-app/.env`

**Critical values to update:**
```env
APP_KEY=<generate-with-openssl-rand-hex-32>
KEYCLOAK_CLIENT_SECRET=<from-keycloak>
DB_PASSWORD=<your-postgres-password>
MINIO_ACCESS_KEY=<your-minio-key>
MINIO_SECRET_KEY=<your-minio-secret>
```

### Python Backend (.env)

Location: `/opt/apps/mxa-ocr/python-backend/.env`

**Critical values to update:**
```env
DB_PASSWORD=<same-as-php>
MINIO_ACCESS_KEY=<same-as-php>
MINIO_SECRET_KEY=<same-as-php>
REDIS_PASSWORD=<if-redis-has-auth>
```

## 🔍 Validation & Testing

### Automated Validation

```bash
bash deploy/scripts/post-deploy-validate.sh
```

This checks:
- ✅ All services running (PostgreSQL, Apache, FastAPI, Celery, Redis)
- ✅ Database exists and has tables
- ✅ API endpoints responding
- ✅ Configuration files present
- ✅ MinIO buckets configured
- ✅ No critical errors in logs
- ✅ Disk space and memory usage

### Manual Testing

1. **Test Web Access:**
   ```bash
   curl https://ocr.gismartanalytics.com/
   ```

2. **Test Python API:**
   ```bash
   curl http://192.168.1.90:8100/api/v1/health
   ```

3. **Test Database:**
   ```bash
   ssh root@192.168.1.66
   sudo -u postgres psql -d mxa_ocr -c "SELECT COUNT(*) FROM users;"
   ```

4. **Test MinIO:**
   ```bash
   ssh root@192.168.1.90
   mc ls mxaocr/
   ```

## 🔄 Rollback Procedure

If something goes wrong:

```bash
cd deploy/scripts
bash rollback.sh
```

The script will:
1. List available previous releases
2. Let you select which one to rollback to
3. Create backup of current state
4. Stop services
5. Update symlinks to previous release
6. Restart services
7. Verify rollback

## 📊 Monitoring

### Service Status

```bash
# On Python Server
ssh root@192.168.1.90
systemctl status mxa-ocr-api
systemctl status mxa-ocr-worker

# On App Server
ssh root@192.168.1.66
systemctl status apache2
systemctl status postgresql
```

### View Logs

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

## 🎓 Script Features

### deploy-master.sh
- ✅ Color-coded output for easy reading
- ✅ Progress indicators for each step
- ✅ Error handling with exit on failure
- ✅ Interactive prompts for safety
- ✅ Automated SSH connection testing
- ✅ Git-based or local deployment
- ✅ Creates timestamped releases
- ✅ Symlink management for easy rollback

### pre-deploy-check.sh
- ✅ Comprehensive prerequisite validation
- ✅ Network connectivity tests
- ✅ SSH access verification
- ✅ Service status checks
- ✅ Disk space monitoring
- ✅ Software version verification
- ✅ Clear pass/fail indicators

### post-deploy-validate.sh
- ✅ 40+ validation checks
- ✅ Service status verification
- ✅ API endpoint testing
- ✅ Database validation
- ✅ File system checks
- ✅ Log analysis
- ✅ Resource usage monitoring
- ✅ Configuration validation

## 🔒 Security Considerations

The scripts include:
- ✅ No hardcoded credentials
- ✅ .env file permission management (chmod 600)
- ✅ Proper file ownership (www-data for PHP, mxa-ocr for Python)
- ✅ SSH key-based authentication recommended
- ✅ Debug mode checking in validation
- ✅ Secure MinIO bucket policies

## 📞 Support & Troubleshooting

### Common Issues

1. **SSH Connection Failed**
   - Verify SSH keys: `ssh-copy-id root@192.168.1.66`
   - Test connection: `ssh root@192.168.1.66 "echo test"`

2. **Service Won't Start**
   - Check logs: `journalctl -u mxa-ocr-api -n 50`
   - Verify .env file: `cat /opt/apps/mxa-ocr/python-backend/.env`

3. **Database Connection Failed**
   - Test connection: `psql -U mxa_ocr_user -d mxa_ocr -h localhost`
   - Check PostgreSQL logs: `tail -f /var/log/postgresql/*.log`

4. **API Not Responding**
   - Check if listening: `netstat -tlnp | grep 8100`
   - Test locally: `curl http://localhost:8100/api/v1/health`

### Getting Help

1. Run validation: `bash post-deploy-validate.sh`
2. Check service logs (commands above)
3. Review [docs/troubleshooting.md](../docs/troubleshooting.md)
4. Check [deploy/scripts/README.md](scripts/README.md) for detailed usage

## ✨ What Makes These Scripts Production-Ready

1. **Idempotent** - Safe to run multiple times
2. **Error Handling** - Fails fast with clear error messages
3. **Validation** - Pre and post deployment checks
4. **Rollback** - Easy revert if something goes wrong
5. **Logging** - Color-coded output with progress indicators
6. **Flexibility** - Environment variables for customization
7. **Documentation** - Comprehensive guides and inline comments
8. **Security** - Proper permissions and credential handling
9. **Testing** - Includes development/testing deployment option
10. **Maintenance** - Easy service management and log viewing

## 🎉 Ready to Deploy!

You now have everything you need to deploy MXA OCR to production:

```bash
# From your local machine or CI/CD
cd /path/to/ocr/deploy/scripts

# 1. Check everything
bash pre-deploy-check.sh

# 2. Deploy
bash deploy-master.sh

# 3. Validate
bash post-deploy-validate.sh

# 4. Done! 🎉
```

---

**Created:** 2026-04-10  
**Version:** 1.0.0  
**Status:** Production Ready ✅
