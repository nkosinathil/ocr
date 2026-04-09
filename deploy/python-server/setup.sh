#!/usr/bin/env bash
# ============================================================
# OCR Platform — Python Processing Server Setup (192.168.1.90)
# Run as: sudo bash setup.sh
# This deploys ALONGSIDE the existing MxA application.
# ============================================================
set -euo pipefail

REPO_URL="https://github.com/nkosinathil/ocr.git"
BRANCH="cursor/ocr-platform-871c"
INSTALL_DIR="/opt/ocr"
SERVICE_USER="pyminio"

echo "=========================================="
echo "  OCR Platform — Python Server Setup"
echo "  Server: 192.168.1.90 (pyserver)"
echo "  Coexisting with MxA on port 8000"
echo "  OCR will use port 8001"
echo "=========================================="

# ---- 1. Install Tesseract & Poppler ----
echo ""
echo "==> Step 1: Installing Tesseract OCR and Poppler..."
apt-get update -qq
apt-get install -y -qq \
    tesseract-ocr \
    tesseract-ocr-eng \
    tesseract-ocr-fra \
    tesseract-ocr-deu \
    tesseract-ocr-spa \
    poppler-utils \
    libpq-dev \
    python3-dev
echo "    Tesseract and Poppler installed."

# ---- 2. Clone Repo ----
echo ""
echo "==> Step 2: Cloning OCR platform code..."
if [ -d "${INSTALL_DIR}" ]; then
    cd "${INSTALL_DIR}"
    git fetch origin "${BRANCH}"
    git checkout "${BRANCH}"
    git pull origin "${BRANCH}"
else
    git clone -b "${BRANCH}" "${REPO_URL}" "${INSTALL_DIR}"
fi
chown -R ${SERVICE_USER}:${SERVICE_USER} "${INSTALL_DIR}"
echo "    Cloned to ${INSTALL_DIR}."

# ---- 3. Create Virtual Environment ----
echo ""
echo "==> Step 3: Setting up Python virtual environment..."
cd "${INSTALL_DIR}/python-backend"

if [ ! -d "venv" ]; then
    sudo -u ${SERVICE_USER} python3 -m venv venv
fi

sudo -u ${SERVICE_USER} venv/bin/pip install --upgrade pip
sudo -u ${SERVICE_USER} venv/bin/pip install -r requirements.txt
echo "    Virtual environment ready."

# ---- 4. Create systemd services ----
echo ""
echo "==> Step 4: Creating systemd services..."

cat > /etc/systemd/system/ocr-api.service << EOF
[Unit]
Description=OCR Platform FastAPI Server (port 8001)
After=network.target redis-server.service docker.service
Wants=redis-server.service docker.service

[Service]
User=${SERVICE_USER}
Group=${SERVICE_USER}
WorkingDirectory=${INSTALL_DIR}/python-backend
EnvironmentFile=${INSTALL_DIR}/python-backend/.env
Environment="PATH=${INSTALL_DIR}/python-backend/venv/bin"
ExecStart=${INSTALL_DIR}/python-backend/venv/bin/gunicorn -w 2 -k uvicorn.workers.UvicornWorker -b 127.0.0.1:8001 app.main:app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/ocr-celery.service << EOF
[Unit]
Description=OCR Platform Celery Worker
After=network.target redis-server.service docker.service
Wants=redis-server.service docker.service

[Service]
User=${SERVICE_USER}
Group=${SERVICE_USER}
WorkingDirectory=${INSTALL_DIR}/python-backend
EnvironmentFile=${INSTALL_DIR}/python-backend/.env
Environment="PATH=${INSTALL_DIR}/python-backend/venv/bin"
ExecStart=${INSTALL_DIR}/python-backend/venv/bin/celery -A app.tasks.celery_app:celery_app worker -l info -Q ocr,default -c 2
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
echo "    Systemd services created."

# ---- 5. Update Nginx to proxy OCR API ----
echo ""
echo "==> Step 5: Updating Nginx configuration..."

NGINX_CONF="/etc/nginx/sites-enabled/default"
if ! grep -q "ocr-api" "$NGINX_CONF" 2>/dev/null; then
    cat >> "$NGINX_CONF" << 'NGINX'

# OCR Platform API (port 8001) — alongside MxA on port 8000
server {
    listen 80;
    server_name ocr.local;

    client_max_body_size 200M;

    location /api/ {
        proxy_pass http://127.0.0.1:8001/;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_read_timeout 3600;
        proxy_send_timeout 3600;
    }
}
NGINX
    nginx -t && systemctl reload nginx
    echo "    Nginx updated with OCR API proxy."
else
    echo "    Nginx already has OCR API config."
fi

# ---- 6. Open firewall port 8001 ----
echo ""
echo "==> Step 6: Opening firewall port 8001..."
ufw allow 8001/tcp 2>/dev/null || true
echo "    Port 8001 opened."

# ---- 7. Start services ----
echo ""
echo "==> Step 7: Starting OCR services..."
systemctl enable ocr-api ocr-celery
systemctl start ocr-api
systemctl start ocr-celery

sleep 3
echo "    Service status:"
systemctl is-active ocr-api && echo "    ocr-api: RUNNING" || echo "    ocr-api: FAILED"
systemctl is-active ocr-celery && echo "    ocr-celery: RUNNING" || echo "    ocr-celery: FAILED"

echo ""
echo "=========================================="
echo "  Python Server Setup Complete!"
echo "=========================================="
echo ""
echo "  Services running alongside MxA:"
echo "    MxA API:     127.0.0.1:8000 (unchanged)"
echo "    OCR API:     127.0.0.1:8001 (new)"
echo "    MxA Celery:  Redis db0/db1 (unchanged)"
echo "    OCR Celery:  Redis db2/db3 (new, isolated)"
echo "    MinIO:       Shared container, separate buckets"
echo ""
echo "  Test: curl http://127.0.0.1:8001/health"
echo "  Logs: journalctl -u ocr-api -f"
echo "        journalctl -u ocr-celery -f"
echo "=========================================="
