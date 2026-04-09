#!/usr/bin/env bash
# ============================================================
# Deep Discovery — App Server (192.168.1.66)
# Run as: sudo bash discover-app-deep.sh
# ============================================================
set -euo pipefail

divider() { echo ""; echo "======== $1 ========"; }

divider "EXISTING APACHE VHOST"
echo "--- gismartanalytics.com.conf ---"
cat /etc/apache2/sites-available/gismartanalytics.com.conf 2>/dev/null || true

divider "EXISTING WEB APPLICATION"
echo "--- /var/www/gismartanalytics structure ---"
find /var/www/gismartanalytics -maxdepth 3 -type f 2>/dev/null | head -60 || true
echo ""
echo "--- composer.json ---"
cat /var/www/gismartanalytics/composer.json 2>/dev/null | head -40 || true
echo ""
echo "--- .env or config ---"
cat /var/www/gismartanalytics/.env 2>/dev/null | head -40 || true

divider "PHP-FPM CONFIG"
echo "--- Pool config ---"
cat /etc/php/8.1/fpm/pool.d/www.conf 2>/dev/null | grep -v '^;' | grep -v '^$' || true
echo ""
echo "--- php.ini upload limits ---"
php -i 2>/dev/null | grep -iE '(upload_max|post_max|memory_limit|max_execution)' || true

divider "PHP-FPM STATUS"
systemctl status php8.1-fpm 2>/dev/null | head -15 || true

divider "CONNECTIVITY TO PYTHON SERVER"
echo "--- Can we reach Python API on 192.168.1.90:8000? ---"
curl -s -o /dev/null -w "HTTP %{http_code}" http://192.168.1.90:8000/health 2>/dev/null || echo "Cannot reach Python API"
echo ""
echo "--- Via port 80 (nginx proxy)? ---"
curl -s -o /dev/null -w "HTTP %{http_code}" http://192.168.1.90/health 2>/dev/null || echo "Cannot reach via nginx"
echo ""

divider "CONNECTIVITY TO SSO SERVER"
echo "--- Can we reach Keycloak on 192.168.1.59? ---"
curl -s -o /dev/null -w "HTTP %{http_code}" http://192.168.1.59/realms/master/.well-known/openid-configuration 2>/dev/null || echo "Cannot reach SSO server"
echo ""

divider "AVAILABLE DISK FOR POSTGRESQL"
echo "--- If we install PostgreSQL here ---"
df -h / | tail -1
echo ""
echo "--- Memory available ---"
free -h | head -2

echo ""
echo "======== APP SERVER DEEP DISCOVERY COMPLETE ========"
