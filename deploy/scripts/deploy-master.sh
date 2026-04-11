#!/bin/bash
# ============================================================================
# MXA OCR - Master Deployment Script
# ============================================================================
# This is the main orchestration script for deploying MXA OCR
# Run this script from your local machine or CI/CD pipeline
# ============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
APP_SERVER="192.168.1.66"
PYTHON_SERVER="192.168.1.90"
SSO_SERVER="192.168.1.59"
SSH_USER="${SSH_USER:-root}"
REPO_URL="${REPO_URL:-https://github.com/nkosinathil/ocr.git}"
BRANCH="${BRANCH:-main}"

# Deployment directories
APP_SERVER_DIR="/var/www/mxa-ocr-app"
PYTHON_SERVER_DIR="/opt/apps/mxa-ocr"

# ============================================================================
# Functions
# ============================================================================

print_header() {
    echo ""
    echo -e "${CYAN}==================================================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}==================================================================${NC}"
    echo ""
}

print_step() {
    echo -e "${YELLOW}>>> $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_ssh_connection() {
    local server=$1
    print_step "Checking SSH connection to $server..."
    if ssh -o ConnectTimeout=5 -o BatchMode=yes ${SSH_USER}@${server} exit 2>/dev/null; then
        print_success "SSH connection to $server successful"
        return 0
    else
        print_error "Cannot connect to $server"
        return 1
    fi
}

# ============================================================================
# Main Deployment Flow
# ============================================================================

print_header "MXA OCR - Master Deployment Script"
echo -e "Target Servers:"
echo -e "  App Server (PHP/DB):  ${GREEN}${APP_SERVER}${NC}"
echo -e "  Python Server:        ${GREEN}${PYTHON_SERVER}${NC}"
echo -e "  SSO Server:           ${GREEN}${SSO_SERVER}${NC}"
echo -e ""
echo -e "Repository:  ${BLUE}${REPO_URL}${NC}"
echo -e "Branch:      ${BLUE}${BRANCH}${NC}"
echo ""

# Confirm deployment
read -p "Do you want to proceed with deployment? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Deployment cancelled."
    exit 0
fi

# ============================================================================
# Step 1: Pre-deployment Checks
# ============================================================================

print_header "Step 1: Pre-deployment Checks"

print_step "Checking SSH connections..."
check_ssh_connection ${APP_SERVER} || exit 1
check_ssh_connection ${PYTHON_SERVER} || exit 1
print_success "All SSH connections verified"

# ============================================================================
# Step 2: Deploy to App Server (192.168.1.66)
# ============================================================================

print_header "Step 2: Deploying to App Server (${APP_SERVER})"

print_step "Uploading deployment package to App Server..."
ssh ${SSH_USER}@${APP_SERVER} "mkdir -p /tmp/mxa-ocr-deploy"

# Create deployment archive
print_step "Creating deployment archive..."
DEPLOY_DIR=$(mktemp -d)
git clone -b ${BRANCH} ${REPO_URL} ${DEPLOY_DIR}/ocr 2>/dev/null || {
    print_info "Using local repository..."
    cp -r . ${DEPLOY_DIR}/ocr
}

cd ${DEPLOY_DIR}
tar -czf mxa-ocr-deploy.tar.gz ocr/
print_success "Deployment archive created"

# Upload to server
print_step "Uploading to App Server..."
scp mxa-ocr-deploy.tar.gz ${SSH_USER}@${APP_SERVER}:/tmp/mxa-ocr-deploy/
print_success "Upload complete"

# Extract and deploy
print_step "Extracting and deploying on App Server..."
ssh ${SSH_USER}@${APP_SERVER} << 'ENDSSH'
set -e
cd /tmp/mxa-ocr-deploy
tar -xzf mxa-ocr-deploy.tar.gz

# Create release directory
RELEASE_DIR="/var/www/mxa-ocr-app/releases/$(date +%Y%m%d-%H%M%S)"
mkdir -p ${RELEASE_DIR}
cp -r ocr/* ${RELEASE_DIR}/

# Update symlink
ln -sfn ${RELEASE_DIR} /var/www/mxa-ocr-app/current

echo "✓ Code deployed to App Server"
ENDSSH

print_success "App Server code deployed"

# ============================================================================
# Step 3: Setup Database
# ============================================================================

print_header "Step 3: Setting up Database on App Server"

ssh ${SSH_USER}@${APP_SERVER} << 'ENDSSH'
set -e
cd /var/www/mxa-ocr-app/current/deploy/scripts
echo "Running database setup..."
sudo -u postgres bash setup-database.sh
ENDSSH

print_success "Database setup complete"

# ============================================================================
# Step 4: Deploy PHP Application
# ============================================================================

print_header "Step 4: Deploying PHP Application"

ssh ${SSH_USER}@${APP_SERVER} << 'ENDSSH'
set -e
cd /var/www/mxa-ocr-app/current/deploy/scripts
echo "Running PHP application setup..."
bash setup-php.sh
ENDSSH

print_success "PHP application deployed"

# Prompt for .env configuration
print_info "IMPORTANT: Update the .env file on App Server"
echo -e "${YELLOW}Run on App Server:${NC}"
echo -e "  ssh ${SSH_USER}@${APP_SERVER}"
echo -e "  nano /var/www/mxa-ocr-app/current/php-app/.env"
echo ""
read -p "Press ENTER when .env has been configured..."

# ============================================================================
# Step 5: Deploy to Python Server (192.168.1.90)
# ============================================================================

print_header "Step 5: Deploying to Python Server (${PYTHON_SERVER})"

print_step "Uploading deployment package to Python Server..."
ssh ${SSH_USER}@${PYTHON_SERVER} "mkdir -p /tmp/mxa-ocr-deploy"
scp ${DEPLOY_DIR}/mxa-ocr-deploy.tar.gz ${SSH_USER}@${PYTHON_SERVER}:/tmp/mxa-ocr-deploy/
print_success "Upload complete"

# Extract and deploy
print_step "Extracting and deploying on Python Server..."
ssh ${SSH_USER}@${PYTHON_SERVER} << 'ENDSSH'
set -e
cd /tmp/mxa-ocr-deploy
tar -xzf mxa-ocr-deploy.tar.gz

# Create application directory
mkdir -p /opt/apps/mxa-ocr
cp -r ocr/* /opt/apps/mxa-ocr/

echo "✓ Code deployed to Python Server"
ENDSSH

print_success "Python Server code deployed"

# ============================================================================
# Step 6: Setup Python Backend
# ============================================================================

print_header "Step 6: Setting up Python Backend"

ssh ${SSH_USER}@${PYTHON_SERVER} << 'ENDSSH'
set -e
cd /opt/apps/mxa-ocr/deploy/scripts
echo "Running Python backend setup..."
bash setup-python.sh
ENDSSH

print_success "Python backend deployed"

# Prompt for .env configuration
print_info "IMPORTANT: Update the .env file on Python Server"
echo -e "${YELLOW}Run on Python Server:${NC}"
echo -e "  ssh ${SSH_USER}@${PYTHON_SERVER}"
echo -e "  nano /opt/apps/mxa-ocr/python-backend/.env"
echo ""
read -p "Press ENTER when .env has been configured..."

# ============================================================================
# Step 7: Setup MinIO
# ============================================================================

print_header "Step 7: Setting up MinIO Storage"

ssh ${SSH_USER}@${PYTHON_SERVER} << 'ENDSSH'
set -e
cd /opt/apps/mxa-ocr/deploy/scripts
if [ -f setup-minio.sh ]; then
    echo "Running MinIO setup..."
    bash setup-minio.sh
else
    echo "MinIO setup script not found. Please configure MinIO manually."
fi
ENDSSH

print_success "MinIO setup complete"

# ============================================================================
# Step 7.1: Sync MinIO Credentials to PHP .env
# ============================================================================

print_step "Syncing MinIO credentials to PHP .env on App Server..."

MINIO_ACCESS_KEY_SYNC="$(ssh ${SSH_USER}@${PYTHON_SERVER} bash -s << 'ENDSSH'
set -e
ENV_FILE="/opt/apps/mxa-ocr/python-backend/.env"
sudo awk -F= '
    /^[[:space:]]*(export[[:space:]]+)?MINIO_ACCESS_KEY[[:space:]]*=/ {
        value=$0
        sub(/^[^=]*=/, "", value)
        sub(/[[:space:]]*#.*/, "", value)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        gsub(/^["'"'"']|["'"'"']$/, "", value)
        result=value
    }
    END { print result }
' "$ENV_FILE"
ENDSSH
)"
MINIO_SECRET_KEY_SYNC="$(ssh ${SSH_USER}@${PYTHON_SERVER} bash -s << 'ENDSSH'
set -e
ENV_FILE="/opt/apps/mxa-ocr/python-backend/.env"
sudo awk -F= '
    /^[[:space:]]*(export[[:space:]]+)?MINIO_SECRET_KEY[[:space:]]*=/ {
        value=$0
        sub(/^[^=]*=/, "", value)
        sub(/[[:space:]]*#.*/, "", value)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        gsub(/^["'"'"']|["'"'"']$/, "", value)
        result=value
    }
    END { print result }
' "$ENV_FILE"
ENDSSH
)"

if [ -z "$MINIO_ACCESS_KEY_SYNC" ] || [ -z "$MINIO_SECRET_KEY_SYNC" ]; then
    print_error "Failed to read MinIO credentials from Python .env"
    exit 1
fi

ssh ${SSH_USER}@${APP_SERVER} bash -s -- "$MINIO_ACCESS_KEY_SYNC" "$MINIO_SECRET_KEY_SYNC" << 'ENDSSH'
set -e
MINIO_ACCESS_KEY_SYNC="$1"
MINIO_SECRET_KEY_SYNC="$2"
ENV_FILE="/var/www/mxa-ocr-app/current/php-app/.env"
TMP_FILE="$(mktemp)"

sudo test -f "$ENV_FILE"
sudo awk -v ak="$MINIO_ACCESS_KEY_SYNC" -v sk="$MINIO_SECRET_KEY_SYNC" '
    BEGIN { updated_access=0; updated_secret=0 }
    {
        if ($0 ~ "^[[:space:]]*(export[[:space:]]+)?MINIO_ACCESS_KEY[[:space:]]*=") {
            print "MINIO_ACCESS_KEY=" ak
            updated_access=1
        } else if ($0 ~ "^[[:space:]]*(export[[:space:]]+)?MINIO_SECRET_KEY[[:space:]]*=") {
            print "MINIO_SECRET_KEY=" sk
            updated_secret=1
        } else {
            print
        }
    }
    END {
        if (updated_access == 0) print "MINIO_ACCESS_KEY=" ak
        if (updated_secret == 0) print "MINIO_SECRET_KEY=" sk
    }
' "$ENV_FILE" > "$TMP_FILE"
sudo cp "$TMP_FILE" "$ENV_FILE"
rm -f "$TMP_FILE"
ENDSSH

print_success "Synced MinIO credentials to PHP .env"

# ============================================================================
# Step 8: Start Services
# ============================================================================

print_header "Step 8: Starting Services"

# Start Python services
print_step "Starting Python services..."
ssh ${SSH_USER}@${PYTHON_SERVER} << 'ENDSSH'
set -e
systemctl start mxa-ocr-api
systemctl start mxa-ocr-worker
systemctl enable mxa-ocr-api
systemctl enable mxa-ocr-worker

echo "✓ Python services started"
ENDSSH

print_success "Python services started"

# Restart Apache
print_step "Restarting Apache..."
ssh ${SSH_USER}@${APP_SERVER} << 'ENDSSH'
set -e
systemctl reload apache2
systemctl status apache2 --no-pager
echo "✓ Apache restarted"
ENDSSH

print_success "Apache restarted"

# ============================================================================
# Step 9: Post-deployment Validation
# ============================================================================

print_header "Step 9: Post-deployment Validation"

print_step "Running validation tests..."
VALIDATION_FAILED=false
PYTHON_VALIDATION_FAILED=false

# Test Python API
print_step "Testing Python API health endpoint..."
PYTHON_HEALTH_OK=false
for _ in {1..6}; do
    if curl -fsS -o /dev/null http://${PYTHON_SERVER}:8100/api/v1/health 2>/dev/null; then
        PYTHON_HEALTH_OK=true
        break
    fi
    sleep 5
done

if [ "$PYTHON_HEALTH_OK" = true ]; then
    print_success "Python API is responding"
else
    print_error "Python API health check failed"
    VALIDATION_FAILED=true
    PYTHON_VALIDATION_FAILED=true
fi

# Test PHP application
print_step "Testing PHP application..."
if ssh ${SSH_USER}@${APP_SERVER} "curl -f http://localhost/ >/dev/null 2>&1"; then
    print_success "PHP application is responding"
else
    print_error "PHP application check failed"
    VALIDATION_FAILED=true
fi

# Check service status
print_step "Checking service status..."
ssh ${SSH_USER}@${PYTHON_SERVER} << 'ENDSSH'
systemctl status mxa-ocr-api --no-pager | head -n 3
systemctl status mxa-ocr-worker --no-pager | head -n 3
ENDSSH

if ! ssh ${SSH_USER}@${PYTHON_SERVER} "systemctl is-active --quiet mxa-ocr-api"; then
    print_error "mxa-ocr-api is not active"
    VALIDATION_FAILED=true
    PYTHON_VALIDATION_FAILED=true
fi

if ! ssh ${SSH_USER}@${PYTHON_SERVER} "systemctl is-active --quiet mxa-ocr-worker"; then
    print_error "mxa-ocr-worker is not active"
    VALIDATION_FAILED=true
    PYTHON_VALIDATION_FAILED=true
fi

if [ "$VALIDATION_FAILED" = true ]; then
    print_error "Post-deployment validation failed"
    if [ "$PYTHON_VALIDATION_FAILED" = true ]; then
        ssh ${SSH_USER}@${PYTHON_SERVER} << 'ENDSSH'
journalctl -u mxa-ocr-api -n 120 --no-pager
journalctl -u mxa-ocr-worker -n 120 --no-pager
ENDSSH
    fi
    exit 1
fi

# ============================================================================
# Deployment Complete
# ============================================================================

print_header "Deployment Complete!"

echo -e "${GREEN}✓ All deployment steps completed successfully${NC}"
echo ""
echo -e "${CYAN}Next Steps:${NC}"
echo ""
echo -e "1. ${YELLOW}Configure Keycloak${NC}"
echo -e "   - Login to: http://${SSO_SERVER}:8080"
echo -e "   - Create client: mxa-ocr-web"
echo -e "   - Configure redirect URIs"
echo -e "   - Update PHP .env with client secret"
echo ""
echo -e "2. ${YELLOW}Verify Deployment${NC}"
echo -e "   - Visit: https://ocr.gismartanalytics.com"
echo -e "   - Test authentication flow"
echo -e "   - Upload a test document"
echo ""
echo -e "3. ${YELLOW}Monitor Logs${NC}"
echo -e "   - Python API:    journalctl -u mxa-ocr-api -f"
echo -e "   - Celery Worker: journalctl -u mxa-ocr-worker -f"
echo -e "   - Apache:        tail -f /var/log/apache2/mxa-ocr-error.log"
echo ""
echo -e "4. ${YELLOW}Setup Monitoring${NC}"
echo -e "   - Configure health check alerts"
echo -e "   - Setup log aggregation"
echo -e "   - Configure backup procedures"
echo ""
echo -e "${BLUE}Deployment timestamp: $(date)${NC}"
echo ""

# Cleanup
rm -rf ${DEPLOY_DIR}

exit 0
