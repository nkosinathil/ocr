#!/bin/bash
# ============================================================================
# MXA OCR - Post-Deployment Validation Script
# ============================================================================
# Run this script after deployment to verify everything is working
# ============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
APP_SERVER="${APP_SERVER:-192.168.1.66}"
PYTHON_SERVER="${PYTHON_SERVER:-192.168.1.90}"
APP_URL="${APP_URL:-https://ocr.gismartanalytics.com}"
SSH_USER="${SSH_USER:-root}"

TESTS_PASSED=0
TESTS_FAILED=0

# ============================================================================
# Helper Functions
# ============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}==================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}==================================================================${NC}"
    echo ""
}

test_pass() {
    echo -e "${GREEN}✓ PASS${NC} - $1"
    ((TESTS_PASSED++))
}

test_fail() {
    echo -e "${RED}✗ FAIL${NC} - $1"
    ((TESTS_FAILED++))
}

test_warn() {
    echo -e "${YELLOW}⚠ WARN${NC} - $1"
}

# ============================================================================
# Validation Tests
# ============================================================================

print_header "MXA OCR - Post-Deployment Validation"

echo "Validating deployment on:"
echo "  App Server:      ${APP_SERVER}"
echo "  Python Server:   ${PYTHON_SERVER}"
echo "  Application URL: ${APP_URL}"
echo ""

# ============================================================================
# Service Status Checks
# ============================================================================

print_header "Service Status Checks"

# Check PostgreSQL
echo -n "Checking PostgreSQL... "
if ssh ${SSH_USER}@${APP_SERVER} "systemctl is-active postgresql" 2>/dev/null | grep -q "active"; then
    test_pass "PostgreSQL is running"
else
    test_fail "PostgreSQL is not running"
fi

# Check Apache
echo -n "Checking Apache... "
if ssh ${SSH_USER}@${APP_SERVER} "systemctl is-active apache2" 2>/dev/null | grep -q "active"; then
    test_pass "Apache is running"
else
    test_fail "Apache is not running"
fi

# Check FastAPI service
echo -n "Checking FastAPI service... "
if ssh ${SSH_USER}@${PYTHON_SERVER} "systemctl is-active mxa-ocr-api" 2>/dev/null | grep -q "active"; then
    test_pass "FastAPI service is running"
else
    test_fail "FastAPI service is not running"
fi

# Check Celery worker
echo -n "Checking Celery worker... "
if ssh ${SSH_USER}@${PYTHON_SERVER} "systemctl is-active mxa-ocr-worker" 2>/dev/null | grep -q "active"; then
    test_pass "Celery worker is running"
else
    test_fail "Celery worker is not running"
fi

# Check Redis
echo -n "Checking Redis... "
if ssh ${SSH_USER}@${PYTHON_SERVER} "systemctl is-active redis-server 2>/dev/null || systemctl is-active redis 2>/dev/null" | grep -q "active"; then
    test_pass "Redis is running"
else
    test_fail "Redis is not running"
fi

# ============================================================================
# Database Checks
# ============================================================================

print_header "Database Checks"

# Check database existence
echo -n "Checking database existence... "
if ssh ${SSH_USER}@${APP_SERVER} "sudo -u postgres psql -lqt | cut -d \\| -f 1 | grep -qw mxa_ocr"; then
    test_pass "Database 'mxa_ocr' exists"
else
    test_fail "Database 'mxa_ocr' does not exist"
fi

# Check database tables
echo -n "Checking database tables... "
TABLE_COUNT=$(ssh ${SSH_USER}@${APP_SERVER} "sudo -u postgres psql -d mxa_ocr -tAc \"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'\"" 2>/dev/null)
if [ "$TABLE_COUNT" -gt 0 ]; then
    test_pass "Database has ${TABLE_COUNT} tables"
else
    test_fail "Database has no tables"
fi

# ============================================================================
# API Endpoint Checks
# ============================================================================

print_header "API Endpoint Checks"

# Test Python API health endpoint
echo -n "Testing Python API health endpoint... "
API_RESPONSE=$(curl -s -w "\n%{http_code}" http://${PYTHON_SERVER}:8100/api/v1/health 2>/dev/null)
HTTP_CODE=$(echo "$API_RESPONSE" | tail -n 1)
if [ "$HTTP_CODE" = "200" ]; then
    test_pass "Python API health endpoint responding (HTTP 200)"
else
    test_fail "Python API health endpoint failed (HTTP $HTTP_CODE)"
fi

# Test Python API root endpoint
echo -n "Testing Python API root endpoint... "
API_RESPONSE=$(curl -s -w "\n%{http_code}" http://${PYTHON_SERVER}:8100/ 2>/dev/null)
HTTP_CODE=$(echo "$API_RESPONSE" | tail -n 1)
if [ "$HTTP_CODE" = "200" ]; then
    test_pass "Python API root endpoint responding (HTTP 200)"
else
    test_fail "Python API root endpoint failed (HTTP $HTTP_CODE)"
fi

# Test PHP application
echo -n "Testing PHP application... "
PHP_RESPONSE=$(ssh ${SSH_USER}@${APP_SERVER} "curl -s -w '\n%{http_code}' http://localhost/" 2>/dev/null)
HTTP_CODE=$(echo "$PHP_RESPONSE" | tail -n 1)
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
    test_pass "PHP application responding (HTTP $HTTP_CODE)"
else
    test_fail "PHP application failed (HTTP $HTTP_CODE)"
fi

# ============================================================================
# File System Checks
# ============================================================================

print_header "File System Checks"

# Check PHP application directory
echo -n "Checking PHP application directory... "
if ssh ${SSH_USER}@${APP_SERVER} "test -d /var/www/mxa-ocr-app/current/php-app"; then
    test_pass "PHP application directory exists"
else
    test_fail "PHP application directory not found"
fi

# Check PHP .env file
echo -n "Checking PHP .env file... "
if ssh ${SSH_USER}@${APP_SERVER} "test -f /var/www/mxa-ocr-app/current/php-app/.env"; then
    test_pass "PHP .env file exists"
else
    test_fail "PHP .env file not found"
fi

# Check Python backend directory
echo -n "Checking Python backend directory... "
if ssh ${SSH_USER}@${PYTHON_SERVER} "test -d /opt/apps/mxa-ocr/python-backend"; then
    test_pass "Python backend directory exists"
else
    test_fail "Python backend directory not found"
fi

# Check Python .env file
echo -n "Checking Python .env file... "
if ssh ${SSH_USER}@${PYTHON_SERVER} "test -f /opt/apps/mxa-ocr/python-backend/.env"; then
    test_pass "Python .env file exists"
else
    test_fail "Python .env file not found"
fi

# Check Python virtual environment
echo -n "Checking Python virtual environment... "
if ssh ${SSH_USER}@${PYTHON_SERVER} "test -d /opt/apps/mxa-ocr/python-backend/venv"; then
    test_pass "Python virtual environment exists"
else
    test_fail "Python virtual environment not found"
fi

# ============================================================================
# Storage Checks
# ============================================================================

print_header "Storage Checks"

# Check MinIO buckets (if mc is installed)
echo -n "Checking MinIO buckets... "
if ssh ${SSH_USER}@${PYTHON_SERVER} "command -v mc &>/dev/null"; then
    BUCKET_COUNT=$(ssh ${SSH_USER}@${PYTHON_SERVER} "mc ls mxaocr 2>/dev/null | wc -l" || echo "0")
    if [ "$BUCKET_COUNT" -ge 2 ]; then
        test_pass "MinIO buckets configured ($BUCKET_COUNT buckets)"
    else
        test_warn "MinIO buckets may not be configured"
    fi
else
    test_warn "MinIO client not installed (skipping bucket check)"
fi

# ============================================================================
# Log Checks
# ============================================================================

print_header "Log Checks"

# Check for Python API errors
echo -n "Checking Python API logs for errors... "
ERROR_COUNT=$(ssh ${SSH_USER}@${PYTHON_SERVER} "journalctl -u mxa-ocr-api --since '10 minutes ago' | grep -i error | wc -l" 2>/dev/null || echo "0")
if [ "$ERROR_COUNT" -eq 0 ]; then
    test_pass "No errors in Python API logs (last 10 minutes)"
else
    test_warn "Found $ERROR_COUNT errors in Python API logs"
fi

# Check for Celery worker errors
echo -n "Checking Celery worker logs for errors... "
ERROR_COUNT=$(ssh ${SSH_USER}@${PYTHON_SERVER} "journalctl -u mxa-ocr-worker --since '10 minutes ago' | grep -i error | wc -l" 2>/dev/null || echo "0")
if [ "$ERROR_COUNT" -eq 0 ]; then
    test_pass "No errors in Celery worker logs (last 10 minutes)"
else
    test_warn "Found $ERROR_COUNT errors in Celery worker logs"
fi

# Check Apache error logs
echo -n "Checking Apache error logs... "
ERROR_COUNT=$(ssh ${SSH_USER}@${APP_SERVER} "tail -n 50 /var/log/apache2/error.log 2>/dev/null | grep -i error | wc -l" || echo "0")
if [ "$ERROR_COUNT" -eq 0 ]; then
    test_pass "No recent errors in Apache logs"
else
    test_warn "Found $ERROR_COUNT errors in Apache logs"
fi

# ============================================================================
# Configuration Checks
# ============================================================================

print_header "Configuration Checks"

# Check if APP_DEBUG is false in PHP
echo -n "Checking PHP APP_DEBUG setting... "
DEBUG_VALUE=$(ssh ${SSH_USER}@${APP_SERVER} "grep APP_DEBUG /var/www/mxa-ocr-app/current/php-app/.env | cut -d= -f2" 2>/dev/null || echo "")
if [ "$DEBUG_VALUE" = "false" ]; then
    test_pass "PHP APP_DEBUG is disabled"
else
    test_warn "PHP APP_DEBUG should be 'false' in production"
fi

# Check if Python APP_DEBUG is False
echo -n "Checking Python APP_DEBUG setting... "
DEBUG_VALUE=$(ssh ${SSH_USER}@${PYTHON_SERVER} "grep APP_DEBUG /opt/apps/mxa-ocr/python-backend/.env | cut -d= -f2" 2>/dev/null || echo "")
if [ "$DEBUG_VALUE" = "False" ]; then
    test_pass "Python APP_DEBUG is disabled"
else
    test_warn "Python APP_DEBUG should be 'False' in production"
fi

# ============================================================================
# Resource Checks
# ============================================================================

print_header "Resource Checks"

# Check disk space on App Server
echo -n "Checking App Server disk space... "
DISK_USAGE=$(ssh ${SSH_USER}@${APP_SERVER} "df -h / | tail -1 | awk '{print \$5}' | sed 's/%//'" 2>/dev/null)
if [ "$DISK_USAGE" -lt 80 ]; then
    test_pass "App Server disk usage: ${DISK_USAGE}%"
else
    test_warn "App Server disk usage is high: ${DISK_USAGE}%"
fi

# Check disk space on Python Server
echo -n "Checking Python Server disk space... "
DISK_USAGE=$(ssh ${SSH_USER}@${PYTHON_SERVER} "df -h / | tail -1 | awk '{print \$5}' | sed 's/%//'" 2>/dev/null)
if [ "$DISK_USAGE" -lt 80 ]; then
    test_pass "Python Server disk usage: ${DISK_USAGE}%"
else
    test_warn "Python Server disk usage is high: ${DISK_USAGE}%"
fi

# Check memory on Python Server
echo -n "Checking Python Server memory... "
MEMORY_USAGE=$(ssh ${SSH_USER}@${PYTHON_SERVER} "free | grep Mem | awk '{print int(\$3/\$2 * 100)}'" 2>/dev/null)
if [ "$MEMORY_USAGE" -lt 90 ]; then
    test_pass "Python Server memory usage: ${MEMORY_USAGE}%"
else
    test_warn "Python Server memory usage is high: ${MEMORY_USAGE}%"
fi

# ============================================================================
# Summary
# ============================================================================

print_header "Validation Summary"

echo ""
echo -e "Tests passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Tests failed: ${RED}${TESTS_FAILED}${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All validation tests passed!${NC}"
    echo -e "The deployment appears to be successful."
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo -e "1. Configure Keycloak client and test authentication"
    echo -e "2. Upload a test document and verify OCR processing"
    echo -e "3. Monitor logs for any issues"
    echo -e "4. Set up monitoring and alerting"
    echo -e "5. Configure SSL certificates"
    echo -e "6. Set up automated backups"
    exit 0
else
    echo -e "${RED}✗ Some validation tests failed!${NC}"
    echo -e "Please investigate and resolve the issues."
    echo ""
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo -e "1. Check service logs: journalctl -u <service-name> -n 50"
    echo -e "2. Verify .env configuration files"
    echo -e "3. Check file permissions"
    echo -e "4. Verify network connectivity"
    echo -e "5. Review deployment logs"
    exit 1
fi
