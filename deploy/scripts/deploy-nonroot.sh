#!/bin/bash
# ============================================================================
# MXA OCR - Non-Root User Deployment Script
# ============================================================================
# This script deploys MXA OCR using non-root SSH users with sudo access
# Each server can have a different SSH username
# ============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration - can be overridden by environment variables or config file
APP_SERVER="${APP_SERVER:-192.168.1.66}"
PYTHON_SERVER="${PYTHON_SERVER:-192.168.1.90}"
SSO_SERVER="${SSO_SERVER:-192.168.1.59}"

# SSH usernames per server (customize these!)
SSH_USER_APP="${SSH_USER_APP:-$USER}"
SSH_USER_PYTHON="${SSH_USER_PYTHON:-$USER}"
SSH_USER_SSO="${SSH_USER_SSO:-$USER}"

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
    local user=$2
    print_step "Checking SSH connection to $user@$server..."
    
    # Try SSH with BatchMode (key-based auth only) and disable strict host key checking
    if ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no ${user}@${server} exit 2>/dev/null; then
        print_success "SSH connection to $user@$server successful"
        return 0
    else
        print_error "Cannot connect to $user@$server"
        echo ""
        print_info "Troubleshooting steps:"
        
        # Check if we can connect with password (not BatchMode)
        print_step "Testing if server is reachable..."
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o PreferredAuthentications=password -o PubkeyAuthentication=no ${user}@${server} exit 2>/dev/null; then
            print_error "Server is reachable but key authentication failed"
            print_info "SSH keys may not be properly set up. Try:"
            print_info "  1. Run: ssh-copy-id $user@$server"
            print_info "  2. Make sure your SSH key is added to ssh-agent:"
            print_info "     eval \$(ssh-agent -s)"
            print_info "     ssh-add ~/.ssh/id_rsa"
        else
            print_error "Cannot reach server at all"
            print_info "Possible issues:"
            print_info "  1. Server is down or unreachable"
            print_info "  2. Firewall blocking connection"
            print_info "  3. Wrong IP address or username"
        fi
        
        # Check for SSH agent
        if [ -z "$SSH_AUTH_SOCK" ]; then
            echo ""
            print_info "SSH agent is not running. Start it with:"
            print_info "  eval \$(ssh-agent -s)"
            print_info "  ssh-add ~/.ssh/id_rsa"
        fi
        
        echo ""
        return 1
    fi
}

check_sudo_access() {
    local server=$1
    local user=$2
    print_step "Checking sudo access on $user@$server..."
    if ssh ${user}@${server} "sudo -n true" 2>/dev/null; then
        print_success "Passwordless sudo is configured"
        return 0
    else
        print_error "Passwordless sudo is not configured"
        print_info "You may be prompted for sudo password during deployment"
        print_info "To configure passwordless sudo, run on the server:"
        print_info "  sudo visudo"
        print_info "  Add line: $user ALL=(ALL) NOPASSWD:ALL"
        return 1
    fi
}

# ============================================================================
# Main Deployment Flow
# ============================================================================

print_header "MXA OCR - Non-Root Deployment Script"
echo -e "${YELLOW}This script uses SSH with non-root users and sudo${NC}"
echo ""
echo -e "Target Servers:"
echo -e "  App Server (PHP/DB):  ${GREEN}${SSH_USER_APP}@${APP_SERVER}${NC}"
echo -e "  Python Server:        ${GREEN}${SSH_USER_PYTHON}@${PYTHON_SERVER}${NC}"
echo -e "  SSO Server:           ${GREEN}${SSH_USER_SSO}@${SSO_SERVER}${NC}"
echo -e ""
echo -e "Repository:  ${BLUE}${REPO_URL}${NC}"
echo -e "Branch:      ${BLUE}${BRANCH}${NC}"
echo ""

# Check if config looks correct
if [ "$SSH_USER_APP" = "$USER" ] && [ "$SSH_USER_PYTHON" = "$USER" ]; then
    print_info "Using current username ($USER) for all servers"
    print_info "To use different usernames, set SSH_USER_APP, SSH_USER_PYTHON, SSH_USER_SSO"
    echo ""
fi

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
check_ssh_connection ${APP_SERVER} ${SSH_USER_APP} || exit 1
check_ssh_connection ${PYTHON_SERVER} ${SSH_USER_PYTHON} || exit 1
print_success "All SSH connections verified"

print_step "Checking sudo access..."
check_sudo_access ${APP_SERVER} ${SSH_USER_APP} || print_info "Continuing anyway..."
check_sudo_access ${PYTHON_SERVER} ${SSH_USER_PYTHON} || print_info "Continuing anyway..."

# ============================================================================
# Step 2: Deploy to App Server (192.168.1.66)
# ============================================================================

print_header "Step 2: Deploying to App Server (${APP_SERVER})"

print_step "Uploading deployment package to App Server..."
ssh ${SSH_USER_APP}@${APP_SERVER} "mkdir -p /tmp/mxa-ocr-deploy"

# Create deployment archive
print_step "Creating deployment archive..."
DEPLOY_DIR=$(mktemp -d)
git clone -b ${BRANCH} ${REPO_URL} ${DEPLOY_DIR}/ocr 2>/dev/null || {
    print_info "Using local repository..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
    cp -r "$REPO_ROOT" ${DEPLOY_DIR}/ocr
}

cd ${DEPLOY_DIR}
tar -czf mxa-ocr-deploy.tar.gz ocr/
print_success "Deployment archive created"

# Upload to server
print_step "Uploading to App Server..."
scp mxa-ocr-deploy.tar.gz ${SSH_USER_APP}@${APP_SERVER}:/tmp/mxa-ocr-deploy/
print_success "Upload complete"

# Extract and deploy
print_step "Extracting and deploying on App Server..."
ssh ${SSH_USER_APP}@${APP_SERVER} << ENDSSH
set -e
cd /tmp/mxa-ocr-deploy
tar -xzf mxa-ocr-deploy.tar.gz

# Create release directory with sudo
RELEASE_DIR="${APP_SERVER_DIR}/releases/\$(date +%Y%m%d-%H%M%S)"
sudo mkdir -p ${APP_SERVER_DIR}/releases
sudo mkdir -p \${RELEASE_DIR}
sudo cp -r ocr/* \${RELEASE_DIR}/

# Update symlink
sudo ln -sfn \${RELEASE_DIR} ${APP_SERVER_DIR}/current

echo "✓ Code deployed to App Server"
ENDSSH

print_success "App Server code deployed"

# ============================================================================
# Step 3: Setup Database
# ============================================================================

print_header "Step 3: Setting up Database on App Server"

ssh ${SSH_USER_APP}@${APP_SERVER} << 'ENDSSH'
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

ssh ${SSH_USER_APP}@${APP_SERVER} << 'ENDSSH'
set -e
cd /var/www/mxa-ocr-app/current/deploy/scripts
echo "Running PHP application setup..."
sudo bash setup-php.sh
ENDSSH

print_success "PHP application deployed"

# Prompt for .env configuration
print_info "IMPORTANT: Update the .env file on App Server"
echo -e "${YELLOW}Run on App Server:${NC}"
echo -e "  ssh ${SSH_USER_APP}@${APP_SERVER}"
echo -e "  sudo nano ${APP_SERVER_DIR}/current/php-app/.env"
echo ""
read -p "Press ENTER when .env has been configured..."

# ============================================================================
# Step 5: Deploy to Python Server (192.168.1.90)
# ============================================================================

print_header "Step 5: Deploying to Python Server (${PYTHON_SERVER})"

print_step "Uploading deployment package to Python Server..."
ssh ${SSH_USER_PYTHON}@${PYTHON_SERVER} "mkdir -p /tmp/mxa-ocr-deploy"
scp ${DEPLOY_DIR}/mxa-ocr-deploy.tar.gz ${SSH_USER_PYTHON}@${PYTHON_SERVER}:/tmp/mxa-ocr-deploy/
print_success "Upload complete"

# Extract and deploy
print_step "Extracting and deploying on Python Server..."
ssh ${SSH_USER_PYTHON}@${PYTHON_SERVER} << ENDSSH
set -e
cd /tmp/mxa-ocr-deploy
tar -xzf mxa-ocr-deploy.tar.gz

# Create application directory with sudo
sudo mkdir -p ${PYTHON_SERVER_DIR}
sudo cp -r ocr/* ${PYTHON_SERVER_DIR}/

echo "✓ Code deployed to Python Server"
ENDSSH

print_success "Python Server code deployed"

# ============================================================================
# Step 6: Setup Python Backend
# ============================================================================

print_header "Step 6: Setting up Python Backend"

ssh ${SSH_USER_PYTHON}@${PYTHON_SERVER} << 'ENDSSH'
set -e
cd /opt/apps/mxa-ocr/deploy/scripts
echo "Running Python backend setup..."
sudo bash setup-python.sh
ENDSSH

print_success "Python backend deployed"

# Prompt for .env configuration
print_info "IMPORTANT: Update the .env file on Python Server"
echo -e "${YELLOW}Run on Python Server:${NC}"
echo -e "  ssh ${SSH_USER_PYTHON}@${PYTHON_SERVER}"
echo -e "  sudo nano ${PYTHON_SERVER_DIR}/python-backend/.env"
echo ""
read -p "Press ENTER when .env has been configured..."

# ============================================================================
# Step 7: Setup MinIO
# ============================================================================

print_header "Step 7: Setting up MinIO Storage"

ssh ${SSH_USER_PYTHON}@${PYTHON_SERVER} << 'ENDSSH'
set -e
cd /opt/apps/mxa-ocr/deploy/scripts
if [ -f setup-minio.sh ]; then
    echo "Running MinIO setup..."
    sudo bash setup-minio.sh
else
    echo "MinIO setup script not found. Please configure MinIO manually."
fi
ENDSSH

print_success "MinIO setup complete"

# ============================================================================
# Step 8: Start Services
# ============================================================================

print_header "Step 8: Starting Services"

# Start Python services
print_step "Starting Python services..."
ssh ${SSH_USER_PYTHON}@${PYTHON_SERVER} << 'ENDSSH'
set -e
sudo systemctl start mxa-ocr-api
sudo systemctl start mxa-ocr-worker
sudo systemctl enable mxa-ocr-api
sudo systemctl enable mxa-ocr-worker

echo "✓ Python services started"
ENDSSH

print_success "Python services started"

# Restart Apache
print_step "Restarting Apache..."
ssh ${SSH_USER_APP}@${APP_SERVER} << 'ENDSSH'
set -e
sudo systemctl reload apache2
sudo systemctl status apache2 --no-pager
echo "✓ Apache restarted"
ENDSSH

print_success "Apache restarted"

# ============================================================================
# Step 9: Post-deployment Validation
# ============================================================================

print_header "Step 9: Post-deployment Validation"

print_step "Running validation tests..."

# Test Python API
print_step "Testing Python API health endpoint..."
if curl -f http://${PYTHON_SERVER}:8100/api/v1/health 2>/dev/null; then
    print_success "Python API is responding"
else
    print_error "Python API health check failed"
fi

# Test PHP application
print_step "Testing PHP application..."
ssh ${SSH_USER_APP}@${APP_SERVER} << 'ENDSSH'
curl -f http://localhost/ 2>/dev/null && echo "✓ PHP application is responding"
ENDSSH

# Check service status
print_step "Checking service status..."
ssh ${SSH_USER_PYTHON}@${PYTHON_SERVER} << 'ENDSSH'
sudo systemctl status mxa-ocr-api --no-pager | head -n 3
sudo systemctl status mxa-ocr-worker --no-pager | head -n 3
ENDSSH

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
echo -e "   - Python API:    ssh ${SSH_USER_PYTHON}@${PYTHON_SERVER} 'sudo journalctl -u mxa-ocr-api -f'"
echo -e "   - Celery Worker: ssh ${SSH_USER_PYTHON}@${PYTHON_SERVER} 'sudo journalctl -u mxa-ocr-worker -f'"
echo -e "   - Apache:        ssh ${SSH_USER_APP}@${APP_SERVER} 'sudo tail -f /var/log/apache2/mxa-ocr-error.log'"
echo ""
echo -e "4. ${YELLOW}SSH Access Commands${NC}"
echo -e "   - App Server:    ssh ${SSH_USER_APP}@${APP_SERVER}"
echo -e "   - Python Server: ssh ${SSH_USER_PYTHON}@${PYTHON_SERVER}"
echo -e "   - SSO Server:    ssh ${SSH_USER_SSO}@${SSO_SERVER}"
echo ""
echo -e "${BLUE}Deployment timestamp: $(date)${NC}"
echo ""

# Cleanup
rm -rf ${DEPLOY_DIR}

exit 0
