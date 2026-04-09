#!/usr/bin/env bash
# ============================================================
# Deep Discovery — Python Server / MxA App (192.168.1.90)
# Run as: sudo bash discover-python-deep.sh
# ============================================================
set -euo pipefail

divider() { echo ""; echo "======== $1 ========"; }

divider "MXA APPLICATION STRUCTURE"
echo "--- /opt/mxa ---"
find /opt/mxa -maxdepth 3 -type f 2>/dev/null | head -60 || true
echo ""
echo "--- /opt/mxa directory tree ---"
ls -laR /opt/mxa/ 2>/dev/null | head -80 || true

divider "MXA VIRTUAL ENV PACKAGES"
/opt/mxa/api/venv/bin/pip list 2>/dev/null || true

divider "MXA API CODE STRUCTURE"
echo "--- Python files ---"
find /opt/mxa -name "*.py" -type f 2>/dev/null | sort || true

divider "MXA MAIN APP FILE"
cat /opt/mxa/api/main.py 2>/dev/null | head -100 || true

divider "MXA CELERY CONFIG"
cat /opt/mxa/api/celery_app.py 2>/dev/null | head -60 || true

divider "MXA ENV / CONFIG"
cat /opt/mxa/api/.env 2>/dev/null || true
cat /opt/mxa/api/config.py 2>/dev/null | head -60 || true
cat /opt/mxa/.env 2>/dev/null || true

divider "MXA SYSTEMD SERVICES"
echo "--- mxa-api.service ---"
systemctl cat mxa-api 2>/dev/null || cat /etc/systemd/system/mxa-api.service 2>/dev/null || true
echo ""
echo "--- mxa-celery.service ---"
systemctl cat mxa-celery 2>/dev/null || cat /etc/systemd/system/mxa-celery.service 2>/dev/null || true

divider "NGINX CONFIG (reverse proxy)"
cat /etc/nginx/sites-enabled/* 2>/dev/null || true
cat /etc/nginx/conf.d/*.conf 2>/dev/null || true

divider "MINIO DOCKER CONTAINER"
docker inspect mxa-minio 2>/dev/null | python3 -m json.tool 2>/dev/null | head -80 || true
echo ""
echo "--- MinIO env / volumes ---"
docker inspect mxa-minio --format='{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null || true
echo ""
echo "--- MinIO data mount ---"
docker inspect mxa-minio --format='{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}' 2>/dev/null || true

divider "MINIO BUCKETS"
echo "--- Check mc client ---"
which mc 2>/dev/null || echo "mc (MinIO client) not in PATH"
mc alias list 2>/dev/null || true
echo ""
echo "--- Try listing buckets via API ---"
curl -s http://127.0.0.1:9000/minio/health/live 2>/dev/null && echo " (MinIO healthy)" || echo "MinIO not reachable on 9000"

divider "REDIS DETAILS"
redis-cli info keyspace 2>/dev/null || true
redis-cli info clients 2>/dev/null || true
echo "--- Redis config (bind, port) ---"
grep -E '^(bind|port|requirepass|maxmemory)' /etc/redis/redis.conf 2>/dev/null || true

divider "GUNICORN / UVICORN WORKER CONFIG"
echo "--- UvicornWorker custom module ---"
cat /opt/mxa/api/uvicorn_worker.py 2>/dev/null || find /opt/mxa -name "uvicorn_worker*" -exec cat {} \; 2>/dev/null || true

divider "MXA REQUIREMENTS"
cat /opt/mxa/api/requirements.txt 2>/dev/null || true

divider "CONNECTIVITY TO APP SERVER DB"
echo "--- Can we reach PostgreSQL on 192.168.1.66? ---"
timeout 3 bash -c 'echo > /dev/tcp/192.168.1.66/5432' 2>/dev/null && echo "YES - port 5432 is reachable" || echo "NO - port 5432 not reachable on 192.168.1.66"

divider "CONNECTIVITY TO SSO SERVER"
echo "--- Can we reach Keycloak on 192.168.1.59? ---"
curl -s -o /dev/null -w "HTTP %{http_code}" http://192.168.1.59/realms/master/.well-known/openid-configuration 2>/dev/null || echo "Cannot reach SSO server"
echo ""

echo ""
echo "======== PYTHON DEEP DISCOVERY COMPLETE ========"
