#!/bin/bash
# ============================================================================
# MXA OCR - Rollback Script
# ============================================================================
# Use this script to rollback to a previous deployment
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
SSH_USER="${SSH_USER:-root}"
APP_DIR="/var/www/mxa-ocr-app"
PYTHON_DIR="/opt/apps/mxa-ocr"

# ============================================================================
# Functions
# ============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}==================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}==================================================================${NC}"
    echo ""
}

print_error() {
    echo -e "${RED}✗ ERROR: $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ WARNING: $1${NC}"
}

# ============================================================================
# Main Rollback Process
# ============================================================================

print_header "MXA OCR - Rollback Script"

echo -e "${RED}WARNING: This will rollback the deployment to a previous version!${NC}"
echo ""
echo "Target Servers:"
echo "  App Server:     ${APP_SERVER}"
echo "  Python Server:  ${PYTHON_SERVER}"
echo ""

# Confirm rollback
read -p "Are you sure you want to rollback? (type 'YES' to confirm): " confirm
if [ "$confirm" != "YES" ]; then
    echo "Rollback cancelled."
    exit 0
fi

# ============================================================================
# Step 1: List Available Releases
# ============================================================================

print_header "Step 1: Available Releases"

echo "Fetching available releases from App Server..."
ssh ${SSH_USER}@${APP_SERVER} << 'ENDSSH'
if [ -d /var/www/mxa-ocr-app/releases ]; then
    echo "Available releases:"
    ls -lt /var/www/mxa-ocr-app/releases | grep ^d | awk '{print NR". "$9}' | head -10
    
    CURRENT=$(readlink /var/www/mxa-ocr-app/current)
    echo ""
    echo "Current release: $(basename $CURRENT)"
else
    echo "No releases directory found!"
    exit 1
fi
ENDSSH

# ============================================================================
# Step 2: Select Release
# ============================================================================

echo ""
echo "Which release would you like to rollback to?"
read -p "Enter release directory name (or 'cancel' to abort): " ROLLBACK_TO

if [ "$ROLLBACK_TO" = "cancel" ]; then
    echo "Rollback cancelled."
    exit 0
fi

if [ -z "$ROLLBACK_TO" ]; then
    print_error "No release specified!"
    exit 1
fi

# ============================================================================
# Step 3: Verify Release Exists
# ============================================================================

print_header "Step 2: Verifying Release"

echo "Verifying release '$ROLLBACK_TO' exists..."
if ! ssh ${SSH_USER}@${APP_SERVER} "test -d /var/www/mxa-ocr-app/releases/$ROLLBACK_TO"; then
    print_error "Release '$ROLLBACK_TO' does not exist!"
    exit 1
fi

print_success "Release verified"

# ============================================================================
# Step 4: Create Backup of Current State
# ============================================================================

print_header "Step 3: Creating Backup"

BACKUP_NAME="pre-rollback-$(date +%Y%m%d-%H%M%S)"

echo "Creating backup of current deployment..."

# Backup App Server
ssh ${SSH_USER}@${APP_SERVER} << ENDSSH
set -e
CURRENT_LINK=\$(readlink /var/www/mxa-ocr-app/current)
if [ -d "/var/www/mxa-ocr-app/backups" ]; then
    echo "Backup directory exists"
else
    mkdir -p /var/www/mxa-ocr-app/backups
fi
echo "Creating backup: ${BACKUP_NAME}"
ln -s \$CURRENT_LINK /var/www/mxa-ocr-app/backups/${BACKUP_NAME}
echo "✓ Backup created on App Server"
ENDSSH

print_success "Backup created"

# ============================================================================
# Step 5: Stop Services
# ============================================================================

print_header "Step 4: Stopping Services"

echo "Stopping Python services..."
ssh ${SSH_USER}@${PYTHON_SERVER} << 'ENDSSH'
systemctl stop mxa-ocr-api
systemctl stop mxa-ocr-worker
echo "✓ Python services stopped"
ENDSSH

print_success "Services stopped"

# ============================================================================
# Step 6: Rollback PHP Application
# ============================================================================

print_header "Step 5: Rolling Back PHP Application"

ssh ${SSH_USER}@${APP_SERVER} << ENDSSH
set -e
echo "Updating symlink to: ${ROLLBACK_TO}"
ln -sfn /var/www/mxa-ocr-app/releases/${ROLLBACK_TO} /var/www/mxa-ocr-app/current

# Restore .env if exists
if [ -f /var/www/mxa-ocr-app/shared/.env ]; then
    cp /var/www/mxa-ocr-app/shared/.env /var/www/mxa-ocr-app/current/php-app/.env
fi

echo "✓ PHP application rolled back"
ENDSSH

print_success "PHP application rolled back"

# ============================================================================
# Step 7: Rollback Python Backend (if release exists)
# ============================================================================

print_header "Step 6: Rolling Back Python Backend"

# Note: Python backend rollback is more complex as we may not have previous releases
# For now, we'll keep the Python backend as is and only rollback PHP
print_warning "Python backend rollback not implemented in this version"
print_warning "If Python backend changes are incompatible, manual intervention required"

# ============================================================================
# Step 8: Restart Services
# ============================================================================

print_header "Step 7: Restarting Services"

# Restart Apache
echo "Restarting Apache..."
ssh ${SSH_USER}@${APP_SERVER} << 'ENDSSH'
systemctl reload apache2
echo "✓ Apache restarted"
ENDSSH

# Restart Python services
echo "Restarting Python services..."
ssh ${SSH_USER}@${PYTHON_SERVER} << 'ENDSSH'
systemctl start mxa-ocr-api
systemctl start mxa-ocr-worker
echo "✓ Python services started"
ENDSSH

print_success "Services restarted"

# ============================================================================
# Step 9: Verify Rollback
# ============================================================================

print_header "Step 8: Verifying Rollback"

echo "Checking service status..."

# Check Apache
echo -n "Apache: "
if ssh ${SSH_USER}@${APP_SERVER} "systemctl is-active apache2" 2>/dev/null | grep -q "active"; then
    echo -e "${GREEN}Running${NC}"
else
    echo -e "${RED}Not Running${NC}"
fi

# Check Python API
echo -n "Python API: "
if ssh ${SSH_USER}@${PYTHON_SERVER} "systemctl is-active mxa-ocr-api" 2>/dev/null | grep -q "active"; then
    echo -e "${GREEN}Running${NC}"
else
    echo -e "${RED}Not Running${NC}"
fi

# Check Celery Worker
echo -n "Celery Worker: "
if ssh ${SSH_USER}@${PYTHON_SERVER} "systemctl is-active mxa-ocr-worker" 2>/dev/null | grep -q "active"; then
    echo -e "${GREEN}Running${NC}"
else
    echo -e "${RED}Not Running${NC}"
fi

# Test API endpoint
echo ""
echo "Testing API endpoint..."
sleep 3
if curl -f -s http://${PYTHON_SERVER}:8100/api/v1/health &>/dev/null; then
    print_success "API is responding"
else
    print_error "API is not responding"
fi

# ============================================================================
# Completion
# ============================================================================

print_header "Rollback Complete"

echo -e "${GREEN}✓ Rollback completed successfully${NC}"
echo ""
echo "Rolled back to: ${ROLLBACK_TO}"
echo "Backup created: ${BACKUP_NAME}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Test the application thoroughly"
echo "2. Monitor logs for any issues"
echo "3. If issues persist, investigate the root cause"
echo "4. Consider rolling forward with a fix instead of staying on old version"
echo ""
echo -e "${YELLOW}View logs:${NC}"
echo "  Apache:        tail -f /var/log/apache2/mxa-ocr-error.log"
echo "  Python API:    journalctl -u mxa-ocr-api -f"
echo "  Celery Worker: journalctl -u mxa-ocr-worker -f"
echo ""
echo -e "${YELLOW}To rollback to the current version later:${NC}"
echo "  Run this script again and select the backup: ${BACKUP_NAME}"
echo ""
