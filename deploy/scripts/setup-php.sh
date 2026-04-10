#!/bin/bash
# ============================================================================
# MXA OCR - PHP Application Setup Script
# ============================================================================
# This script sets up the PHP web frontend
# Run as: sudo ./setup-php.sh
# ============================================================================

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}==================================================================${NC}"
echo -e "${GREEN}MXA OCR - PHP Application Setup${NC}"
echo -e "${GREEN}==================================================================${NC}"
echo ""

# Configuration
APP_DIR="/var/www/mxa-ocr-app"
CURRENT_DIR="$APP_DIR/current"
PHP_APP_DIR="$CURRENT_DIR/php-app"
WEB_USER="www-data"
WEB_GROUP="www-data"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo -e "${YELLOW}Run: sudo $0${NC}"
    exit 1
fi

# Step 1: Create directories
echo -e "${YELLOW}Step 1: Creating application directories...${NC}"
mkdir -p "$APP_DIR"
mkdir -p "$APP_DIR/releases"
mkdir -p "$APP_DIR/shared"

# Step 2: Clone/copy repository (assuming it's already cloned)
echo -e "${YELLOW}Step 2: Setting up application code...${NC}"
if [ ! -d "$CURRENT_DIR" ]; then
    echo -e "${YELLOW}Creating symlink to current release...${NC}"
    # This should point to your actual deployment
    # For now, create a placeholder
    mkdir -p "$CURRENT_DIR"
fi

cd "$PHP_APP_DIR"

# Step 3: Install Composer dependencies
echo -e "${YELLOW}Step 3: Installing Composer dependencies...${NC}"
if [ ! -f "composer.json" ]; then
    echo -e "${RED}Error: composer.json not found${NC}"
    exit 1
fi

# Install Composer if not present
if ! command -v composer &> /dev/null; then
    echo -e "${YELLOW}Installing Composer...${NC}"
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
fi

composer install --no-dev --optimize-autoloader

# Step 4: Configure environment
echo -e "${YELLOW}Step 4: Configuring environment...${NC}"
if [ ! -f ".env" ]; then
    cp .env.example .env
    echo -e "${YELLOW}Created .env file - PLEASE UPDATE WITH ACTUAL VALUES${NC}"
fi

# Step 5: Set permissions
echo -e "${YELLOW}Step 5: Setting file permissions...${NC}"
chown -R $WEB_USER:$WEB_GROUP "$PHP_APP_DIR"
chmod -R 755 "$PHP_APP_DIR"
chmod -R 775 "$PHP_APP_DIR/storage"
chmod 600 "$PHP_APP_DIR/.env"

# Step 6: Configure Apache
echo -e "${YELLOW}Step 6: Configuring Apache...${NC}"

# Enable required Apache modules
a2enmod rewrite
a2enmod ssl
a2enmod headers
a2enmod proxy
a2enmod proxy_http

# Copy and enable vhost
VHOST_SRC="$(dirname "$(dirname "$0")")/apache/mxa-ocr.conf"
if [ -f "$VHOST_SRC" ]; then
    cp "$VHOST_SRC" /etc/apache2/sites-available/mxa-ocr.conf
    a2ensite mxa-ocr
else
    echo -e "${YELLOW}Warning: Apache vhost config not found at $VHOST_SRC${NC}"
fi

# Step 7: Reload Apache
echo -e "${YELLOW}Step 7: Reloading Apache...${NC}"
systemctl reload apache2

echo ""
echo -e "${GREEN}==================================================================${NC}"
echo -e "${GREEN}PHP application setup completed!${NC}"
echo -e "${GREEN}==================================================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Update $PHP_APP_DIR/.env with actual credentials"
echo -e "2. Configure SSL certificates"
echo -e "3. Test: curl http://localhost/api/health"
echo ""
