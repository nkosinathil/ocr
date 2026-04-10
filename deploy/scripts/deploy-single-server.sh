#!/bin/bash
# ============================================================================
# MXA OCR - Single Server Deployment (For Testing/Development)
# ============================================================================
# This script deploys everything on a single server for testing purposes
# NOT recommended for production - use deploy-master.sh instead
# ============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}==================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}==================================================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_header "MXA OCR - Single Server Deployment"

echo -e "${YELLOW}WARNING: This deploys everything on the current server.${NC}"
echo -e "${YELLOW}This is for development/testing only.${NC}"
echo -e "${YELLOW}For production, use deploy-master.sh instead.${NC}"
echo ""

read -p "Continue with single-server deployment? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Deployment cancelled."
    exit 0
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "This script must be run as root"
    echo "Run: sudo bash $0"
    exit 1
fi

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

cd "$SCRIPT_DIR"

# ============================================================================
# Step 1: Install Prerequisites
# ============================================================================

print_header "Step 1: Installing Prerequisites"

echo "Updating package list..."
apt-get update -qq

echo "Installing system packages..."
apt-get install -y \
    postgresql postgresql-contrib \
    apache2 \
    php8.1 php8.1-cli php8.1-fpm php8.1-pgsql php8.1-mbstring php8.1-xml php8.1-curl \
    python3.10 python3.10-venv python3-pip \
    redis-server \
    tesseract-ocr tesseract-ocr-eng \
    poppler-utils \
    curl wget git \
    > /dev/null 2>&1

print_success "Prerequisites installed"

# ============================================================================
# Step 2: Setup Database
# ============================================================================

print_header "Step 2: Setting Up Database"

sudo -u postgres bash setup-database.sh

print_success "Database configured"

# ============================================================================
# Step 3: Setup PHP Application
# ============================================================================

print_header "Step 3: Setting Up PHP Application"

# Create application directory
mkdir -p /var/www/mxa-ocr-app/current
cp -r "$REPO_ROOT"/* /var/www/mxa-ocr-app/current/

cd /var/www/mxa-ocr-app/current

# Install Composer if not present
if ! command -v composer &> /dev/null; then
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
fi

# Install PHP dependencies
cd php-app
composer install --no-dev --no-interaction > /dev/null 2>&1

# Setup .env
if [ ! -f .env ]; then
    cp .env.example .env
    
    # Update for local deployment
    sed -i 's/192.168.1.66/localhost/g' .env
    sed -i 's/192.168.1.90/localhost/g' .env
    sed -i 's/APP_ENV=production/APP_ENV=development/g' .env
    sed -i 's/APP_DEBUG=false/APP_DEBUG=true/g' .env
fi

# Set permissions
chown -R www-data:www-data /var/www/mxa-ocr-app
chmod -R 755 /var/www/mxa-ocr-app
chmod -R 775 php-app/storage
chmod 600 .env

print_success "PHP application configured"

# ============================================================================
# Step 4: Configure Apache
# ============================================================================

print_header "Step 4: Configuring Apache"

# Enable required modules
a2enmod rewrite headers proxy proxy_http > /dev/null 2>&1

# Create simple vhost for local testing
cat > /etc/apache2/sites-available/mxa-ocr-local.conf <<'EOF'
<VirtualHost *:80>
    ServerName localhost
    DocumentRoot /var/www/mxa-ocr-app/current/php-app/public

    <Directory /var/www/mxa-ocr-app/current/php-app/public>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/mxa-ocr-error.log
    CustomLog ${APACHE_LOG_DIR}/mxa-ocr-access.log combined
</VirtualHost>
EOF

a2dissite 000-default > /dev/null 2>&1 || true
a2ensite mxa-ocr-local > /dev/null 2>&1
systemctl reload apache2

print_success "Apache configured"

# ============================================================================
# Step 5: Setup Python Backend
# ============================================================================

print_header "Step 5: Setting Up Python Backend"

# Create application directory
mkdir -p /opt/apps/mxa-ocr
cp -r "$REPO_ROOT"/* /opt/apps/mxa-ocr/

cd /opt/apps/mxa-ocr/python-backend

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install --quiet --upgrade pip > /dev/null 2>&1
pip install --quiet -r requirements.txt > /dev/null 2>&1

# Setup .env
if [ ! -f .env ]; then
    cp .env.example .env
    
    # Update for local deployment
    sed -i 's/192.168.1.66/localhost/g' .env
    sed -i 's/192.168.1.90/localhost/g' .env
    sed -i 's/APP_ENV=production/APP_ENV=development/g' .env
    sed -i 's/APP_DEBUG=False/APP_DEBUG=True/g' .env
fi

chmod 600 .env

print_success "Python backend configured"

# ============================================================================
# Step 6: Install Systemd Services
# ============================================================================

print_header "Step 6: Installing Services"

# Copy service files
cp "$REPO_ROOT/deploy/systemd/mxa-ocr-api.service" /etc/systemd/system/
cp "$REPO_ROOT/deploy/systemd/mxa-ocr-worker.service" /etc/systemd/system/

# Reload systemd
systemctl daemon-reload

# Enable services
systemctl enable mxa-ocr-api > /dev/null 2>&1
systemctl enable mxa-ocr-worker > /dev/null 2>&1

# Start services
systemctl start mxa-ocr-api
systemctl start mxa-ocr-worker

print_success "Services started"

# ============================================================================
# Step 7: Verify Installation
# ============================================================================

print_header "Step 7: Verifying Installation"

sleep 3

# Check services
echo -n "PostgreSQL: "
systemctl is-active postgresql && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"

echo -n "Apache: "
systemctl is-active apache2 && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"

echo -n "Redis: "
systemctl is-active redis-server && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"

echo -n "Python API: "
systemctl is-active mxa-ocr-api && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"

echo -n "Celery Worker: "
systemctl is-active mxa-ocr-worker && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"

# Test API
echo ""
echo -n "Testing Python API... "
if curl -f -s http://localhost:8100/api/v1/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

# ============================================================================
# Completion
# ============================================================================

print_header "Deployment Complete!"

echo -e "${GREEN}Single-server deployment completed successfully!${NC}"
echo ""
echo -e "${YELLOW}Access Points:${NC}"
echo -e "  Web Application:  http://localhost/"
echo -e "  Python API:       http://localhost:8100/"
echo -e "  API Docs:         http://localhost:8100/docs"
echo ""
echo -e "${YELLOW}Service Management:${NC}"
echo -e "  Restart API:      sudo systemctl restart mxa-ocr-api"
echo -e "  Restart Worker:   sudo systemctl restart mxa-ocr-worker"
echo -e "  Restart Apache:   sudo systemctl reload apache2"
echo ""
echo -e "${YELLOW}View Logs:${NC}"
echo -e "  Python API:       sudo journalctl -u mxa-ocr-api -f"
echo -e "  Celery Worker:    sudo journalctl -u mxa-ocr-worker -f"
echo -e "  Apache:           sudo tail -f /var/log/apache2/mxa-ocr-error.log"
echo ""
echo -e "${YELLOW}Configuration Files:${NC}"
echo -e "  PHP .env:         /var/www/mxa-ocr-app/current/php-app/.env"
echo -e "  Python .env:      /opt/apps/mxa-ocr/python-backend/.env"
echo ""
echo -e "${RED}IMPORTANT:${NC}"
echo -e "1. Update .env files with actual credentials"
echo -e "2. Configure Keycloak for authentication"
echo -e "3. This is a development setup - do not use in production!"
echo ""
