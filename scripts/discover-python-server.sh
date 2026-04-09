#!/usr/bin/env bash
# ============================================================
# Discovery Script — Python Processing Server (192.168.1.90)
# Run as: sudo bash discover-python-server.sh
# ============================================================
set -euo pipefail

divider() { echo ""; echo "======== $1 ========"; }

divider "OS & KERNEL"
cat /etc/os-release 2>/dev/null || echo "N/A"
uname -a
hostnamectl 2>/dev/null || true

divider "HOSTNAME & IP"
hostname -f 2>/dev/null || hostname
ip -4 addr show | grep -E 'inet ' || ifconfig 2>/dev/null | grep 'inet '

divider "DISK & MEMORY"
df -h /
free -h

divider "USERS & GROUPS"
echo "--- System users with shells ---"
grep -vE '(nologin|false)$' /etc/passwd
echo ""
echo "--- All groups ---"
cat /etc/group

divider "PYTHON"
python3 --version 2>/dev/null || echo "Python3 not installed"
python3 -m pip --version 2>/dev/null || true
which python3 2>/dev/null || true
echo "--- Installed pip packages ---"
pip3 list 2>/dev/null || python3 -m pip list 2>/dev/null || true

divider "VIRTUAL ENVS"
find /opt /home /srv -maxdepth 4 -name "activate" -path "*/bin/activate" 2>/dev/null || true

divider "TESSERACT"
tesseract --version 2>/dev/null || echo "Tesseract not installed"
tesseract --list-langs 2>/dev/null || true

divider "POPPLER (pdf2image)"
pdftotext -v 2>&1 | head -2 || echo "poppler-utils not installed"

divider "REDIS"
redis-server --version 2>/dev/null || echo "Redis not installed"
redis-cli ping 2>/dev/null || true
redis-cli info server 2>/dev/null | head -15 || true
systemctl status redis-server 2>/dev/null | head -10 || systemctl status redis 2>/dev/null | head -10 || true

divider "MINIO"
minio --version 2>/dev/null || echo "MinIO binary not found in PATH"
find / -name "minio" -type f 2>/dev/null | head -5 || true
echo "--- MinIO processes ---"
ps aux | grep -i minio | grep -v grep || echo "No MinIO process running"
echo "--- MinIO data dirs ---"
ls -la /data/minio 2>/dev/null || ls -la /mnt/minio 2>/dev/null || echo "No standard MinIO data dir found"

divider "CELERY"
celery --version 2>/dev/null || echo "Celery not installed (globally)"
echo "--- Celery processes ---"
ps aux | grep -i celery | grep -v grep || echo "No Celery workers running"

divider "FASTAPI / UVICORN"
echo "--- Uvicorn processes ---"
ps aux | grep -i uvicorn | grep -v grep || echo "No Uvicorn running"
echo "--- Port 8000 ---"
ss -tlnp | grep 8000 || echo "Nothing on port 8000"

divider "DOCKER"
docker --version 2>/dev/null || echo "Docker not installed"
docker ps -a 2>/dev/null || true

divider "EXISTING APPLICATIONS"
echo "--- /opt contents ---"
ls -la /opt/ 2>/dev/null || true
echo "--- /srv contents ---"
ls -la /srv/ 2>/dev/null || true
echo "--- Home directories ---"
ls -la /home/ 2>/dev/null || true

divider "FIREWALL"
ufw status verbose 2>/dev/null || iptables -L -n 2>/dev/null | head -30 || true

divider "LISTENING PORTS"
ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null || true

divider "SYSTEMD SERVICES (running)"
systemctl list-units --type=service --state=running 2>/dev/null | head -40 || true

divider "ENV VARS (non-sensitive)"
env | grep -iE '(APP_|REDIS|MINIO|CELERY|PYTHON|HOME|PATH|LANG|USER|SHELL)' 2>/dev/null || true

echo ""
echo "======== DISCOVERY COMPLETE (192.168.1.90) ========"
