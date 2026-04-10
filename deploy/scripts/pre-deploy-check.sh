#!/bin/bash
# ============================================================================
# MXA OCR - Pre-deployment Checks
# ============================================================================
# Run this script before deployment to verify all prerequisites
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
SSO_SERVER="${SSO_SERVER:-192.168.1.59}"
SSH_USER="${SSH_USER:-root}"

CHECKS_PASSED=0
CHECKS_FAILED=0

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

check_pass() {
    echo -e "${GREEN}✓ PASS${NC} - $1"
    ((CHECKS_PASSED++))
}

check_fail() {
    echo -e "${RED}✗ FAIL${NC} - $1"
    ((CHECKS_FAILED++))
}

check_warn() {
    echo -e "${YELLOW}⚠ WARN${NC} - $1"
}

# ============================================================================
# Checks
# ============================================================================

print_header "MXA OCR - Pre-deployment Checks"

echo "Target Servers:"
echo "  App Server:     ${APP_SERVER}"
echo "  Python Server:  ${PYTHON_SERVER}"
echo "  SSO Server:     ${SSO_SERVER}"
echo ""

# ============================================================================
# Network Connectivity Checks
# ============================================================================

print_header "Network Connectivity"

# Check App Server
echo -n "Checking App Server (${APP_SERVER})... "
if ping -c 1 -W 2 ${APP_SERVER} &>/dev/null; then
    check_pass "App Server is reachable"
else
    check_fail "App Server is not reachable"
fi

# Check Python Server
echo -n "Checking Python Server (${PYTHON_SERVER})... "
if ping -c 1 -W 2 ${PYTHON_SERVER} &>/dev/null; then
    check_pass "Python Server is reachable"
else
    check_fail "Python Server is not reachable"
fi

# Check SSO Server
echo -n "Checking SSO Server (${SSO_SERVER})... "
if ping -c 1 -W 2 ${SSO_SERVER} &>/dev/null; then
    check_pass "SSO Server is reachable"
else
    check_fail "SSO Server is not reachable"
fi

# ============================================================================
# SSH Connectivity Checks
# ============================================================================

print_header "SSH Connectivity"

# Check App Server SSH
echo -n "Checking SSH to App Server... "
if ssh -o ConnectTimeout=5 -o BatchMode=yes ${SSH_USER}@${APP_SERVER} exit 2>/dev/null; then
    check_pass "SSH connection to App Server successful"
else
    check_fail "Cannot SSH to App Server (check keys/credentials)"
fi

# Check Python Server SSH
echo -n "Checking SSH to Python Server... "
if ssh -o ConnectTimeout=5 -o BatchMode=yes ${SSH_USER}@${PYTHON_SERVER} exit 2>/dev/null; then
    check_pass "SSH connection to Python Server successful"
else
    check_fail "Cannot SSH to Python Server (check keys/credentials)"
fi

# ============================================================================
# App Server Prerequisites
# ============================================================================

print_header "App Server Prerequisites (${APP_SERVER})"

# Check PostgreSQL
echo -n "Checking PostgreSQL... "
if ssh ${SSH_USER}@${APP_SERVER} "systemctl is-active postgresql" 2>/dev/null | grep -q "active"; then
    check_pass "PostgreSQL is running"
else
    check_fail "PostgreSQL is not running"
fi

# Check Apache
echo -n "Checking Apache... "
if ssh ${SSH_USER}@${APP_SERVER} "systemctl is-active apache2" 2>/dev/null | grep -q "active"; then
    check_pass "Apache is running"
else
    check_fail "Apache is not running"
fi

# Check PHP
echo -n "Checking PHP... "
PHP_VERSION=$(ssh ${SSH_USER}@${APP_SERVER} "php -v 2>/dev/null | head -n 1" || echo "")
if echo "$PHP_VERSION" | grep -q "PHP 8"; then
    check_pass "PHP 8.x is installed: $PHP_VERSION"
else
    check_fail "PHP 8.x is not installed or not accessible"
fi

# Check Composer
echo -n "Checking Composer... "
if ssh ${SSH_USER}@${APP_SERVER} "command -v composer" &>/dev/null; then
    check_pass "Composer is installed"
else
    check_warn "Composer is not installed (will be installed during deployment)"
fi

# Check disk space
echo -n "Checking disk space... "
DISK_USAGE=$(ssh ${SSH_USER}@${APP_SERVER} "df -h / | tail -1 | awk '{print \$5}' | sed 's/%//'" 2>/dev/null)
if [ "$DISK_USAGE" -lt 80 ]; then
    check_pass "Disk usage: ${DISK_USAGE}%"
else
    check_warn "Disk usage is high: ${DISK_USAGE}%"
fi

# ============================================================================
# Python Server Prerequisites
# ============================================================================

print_header "Python Server Prerequisites (${PYTHON_SERVER})"

# Check Python
echo -n "Checking Python... "
PYTHON_VERSION=$(ssh ${SSH_USER}@${PYTHON_SERVER} "python3 --version 2>/dev/null" || echo "")
if echo "$PYTHON_VERSION" | grep -q "Python 3.1"; then
    check_pass "Python 3.10+ is installed: $PYTHON_VERSION"
else
    check_fail "Python 3.10+ is not installed"
fi

# Check Redis
echo -n "Checking Redis... "
if ssh ${SSH_USER}@${PYTHON_SERVER} "systemctl is-active redis-server 2>/dev/null || systemctl is-active redis 2>/dev/null" | grep -q "active"; then
    check_pass "Redis is running"
else
    check_fail "Redis is not running"
fi

# Check Tesseract
echo -n "Checking Tesseract... "
if ssh ${SSH_USER}@${PYTHON_SERVER} "command -v tesseract" &>/dev/null; then
    TESS_VERSION=$(ssh ${SSH_USER}@${PYTHON_SERVER} "tesseract --version 2>&1 | head -1")
    check_pass "Tesseract is installed: $TESS_VERSION"
else
    check_warn "Tesseract is not installed (will be installed during deployment)"
fi

# Check MinIO
echo -n "Checking MinIO... "
if ssh ${SSH_USER}@${PYTHON_SERVER} "curl -f http://localhost:9000/minio/health/live 2>/dev/null" | grep -q ""; then
    check_pass "MinIO is running"
else
    check_warn "MinIO is not responding (may need configuration)"
fi

# Check disk space
echo -n "Checking disk space... "
DISK_USAGE=$(ssh ${SSH_USER}@${PYTHON_SERVER} "df -h / | tail -1 | awk '{print \$5}' | sed 's/%//'" 2>/dev/null)
if [ "$DISK_USAGE" -lt 80 ]; then
    check_pass "Disk usage: ${DISK_USAGE}%"
else
    check_warn "Disk usage is high: ${DISK_USAGE}%"
fi

# ============================================================================
# SSO Server Check
# ============================================================================

print_header "SSO Server Check (${SSO_SERVER})"

# Check Keycloak
echo -n "Checking Keycloak... "
if curl -f -s http://${SSO_SERVER}:8080/ &>/dev/null; then
    check_pass "Keycloak is accessible"
else
    check_warn "Keycloak is not accessible on port 8080"
fi

# ============================================================================
# Local Prerequisites
# ============================================================================

print_header "Local Prerequisites"

# Check git
echo -n "Checking git... "
if command -v git &>/dev/null; then
    check_pass "git is installed"
else
    check_fail "git is not installed"
fi

# Check tar
echo -n "Checking tar... "
if command -v tar &>/dev/null; then
    check_pass "tar is installed"
else
    check_fail "tar is not installed"
fi

# Check scp/rsync
echo -n "Checking scp... "
if command -v scp &>/dev/null; then
    check_pass "scp is installed"
else
    check_fail "scp is not installed"
fi

# ============================================================================
# Summary
# ============================================================================

print_header "Check Summary"

echo ""
echo -e "Checks passed: ${GREEN}${CHECKS_PASSED}${NC}"
echo -e "Checks failed: ${RED}${CHECKS_FAILED}${NC}"
echo ""

if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All critical checks passed!${NC}"
    echo -e "You can proceed with deployment."
    echo ""
    echo -e "Run: ${YELLOW}bash deploy/scripts/deploy-master.sh${NC}"
    exit 0
else
    echo -e "${RED}✗ Some checks failed!${NC}"
    echo -e "Please resolve the issues before deploying."
    echo ""
    echo -e "Common solutions:"
    echo -e "  - Install missing software"
    echo -e "  - Start required services"
    echo -e "  - Configure SSH key authentication"
    echo -e "  - Check firewall rules"
    exit 1
fi
