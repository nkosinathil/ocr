#!/bin/bash
# ============================================================================
# MXA OCR - Python Backend Setup Script
# ============================================================================
# This script sets up the Python backend (FastAPI + Celery)
# Run as: sudo ./setup-python.sh
# ============================================================================

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}==================================================================${NC}"
echo -e "${GREEN}MXA OCR - Python Backend Setup${NC}"
echo -e "${GREEN}==================================================================${NC}"
echo ""

# Configuration
APP_DIR="/opt/apps/mxa-ocr"
PYTHON_BACKEND_DIR="$APP_DIR/python-backend"
APP_USER="mxa-ocr"
APP_GROUP="mxa-ocr"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(dirname "$SCRIPT_DIR")"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo -e "${YELLOW}Run: sudo $0${NC}"
    exit 1
fi

# Step 1: Create system user
echo -e "${YELLOW}Step 1: Creating system user...${NC}"
if ! id "$APP_USER" &>/dev/null; then
    useradd -r -s /bin/bash -d "$APP_DIR" -m "$APP_USER"
    echo -e "${GREEN}User $APP_USER created${NC}"
else
    echo -e "${YELLOW}User $APP_USER already exists${NC}"
fi

# Step 2: Create directories
echo -e "${YELLOW}Step 2: Creating application directories...${NC}"
mkdir -p "$APP_DIR"
mkdir -p /var/log/mxa-ocr
mkdir -p /tmp/mxa-ocr
mkdir -p /var/run/mxa-ocr

chown -R $APP_USER:$APP_GROUP "$APP_DIR"
chown -R $APP_USER:$APP_GROUP /var/log/mxa-ocr
chown -R $APP_USER:$APP_GROUP /tmp/mxa-ocr
chown -R $APP_USER:$APP_GROUP /var/run/mxa-ocr

# Step 3: Install system dependencies
echo -e "${YELLOW}Step 3: Installing system dependencies...${NC}"
apt-get update
apt-get install -y \
    python3.10 \
    python3.10-venv \
    python3-pip \
    tesseract-ocr \
    tesseract-ocr-eng \
    tesseract-ocr-afr \
    poppler-utils \
    libtesseract-dev \
    redis-tools \
    postgresql-client

# Step 4: Create virtual environment
echo -e "${YELLOW}Step 4: Creating Python virtual environment...${NC}"
cd "$PYTHON_BACKEND_DIR"

if [ ! -d "venv" ]; then
    sudo -u $APP_USER python3 -m venv venv
    echo -e "${GREEN}Virtual environment created${NC}"
else
    echo -e "${YELLOW}Virtual environment already exists${NC}"
fi

# Step 5: Install Python dependencies
echo -e "${YELLOW}Step 5: Installing Python dependencies...${NC}"
sudo -u $APP_USER venv/bin/pip install --upgrade pip
sudo -u $APP_USER venv/bin/pip install -r requirements.txt

# Step 6: Configure environment
echo -e "${YELLOW}Step 6: Configuring environment...${NC}"
if [ ! -f ".env" ]; then
    sudo -u $APP_USER cp .env.example .env
    echo -e "${YELLOW}Created .env file - PLEASE UPDATE WITH ACTUAL VALUES${NC}"
fi
chmod 600 .env
chown $APP_USER:$APP_GROUP .env

# Step 7: Install systemd services
echo -e "${YELLOW}Step 7: Installing systemd services...${NC}"

# FastAPI service
FASTAPI_SERVICE_SRC="$DEPLOY_DIR/systemd/mxa-ocr-api.service"
if [ -f "$FASTAPI_SERVICE_SRC" ]; then
    cp "$FASTAPI_SERVICE_SRC" /etc/systemd/system/
    echo -e "${GREEN}FastAPI service installed${NC}"
else
    echo -e "${RED}Error: FastAPI service file not found${NC}"
fi

# Celery worker service
CELERY_SERVICE_SRC="$DEPLOY_DIR/systemd/mxa-ocr-worker.service"
if [ -f "$CELERY_SERVICE_SRC" ]; then
    cp "$CELERY_SERVICE_SRC" /etc/systemd/system/
    echo -e "${GREEN}Celery worker service installed${NC}"
else
    echo -e "${RED}Error: Celery worker service file not found${NC}"
fi

# Reload systemd
systemctl daemon-reload

# Step 8: Enable and start services
echo -e "${YELLOW}Step 8: Enabling services...${NC}"
systemctl enable mxa-ocr-api
systemctl enable mxa-ocr-worker

echo ""
echo -e "${GREEN}==================================================================${NC}"
echo -e "${GREEN}Python backend setup completed!${NC}"
echo -e "${GREEN}==================================================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Update $PYTHON_BACKEND_DIR/.env with actual credentials"
echo -e "2. Start services:"
echo -e "   sudo systemctl start mxa-ocr-api"
echo -e "   sudo systemctl start mxa-ocr-worker"
echo -e "3. Check status:"
echo -e "   sudo systemctl status mxa-ocr-api"
echo -e "   sudo systemctl status mxa-ocr-worker"
echo -e "4. View logs:"
echo -e "   journalctl -u mxa-ocr-api -f"
echo -e "   journalctl -u mxa-ocr-worker -f"
echo ""
