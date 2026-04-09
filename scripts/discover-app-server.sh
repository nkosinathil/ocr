#!/usr/bin/env bash
# ============================================================
# Discovery Script — Application Server (192.168.1.66)
# Run as: sudo bash discover-app-server.sh
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

divider "PHP"
php -v 2>/dev/null || echo "PHP not installed"
php -m 2>/dev/null || true
php -i 2>/dev/null | grep -i "loaded configuration" || true

divider "APACHE / HTTPD"
apache2 -v 2>/dev/null || httpd -v 2>/dev/null || echo "Apache not found"
echo "--- Enabled sites ---"
ls -la /etc/apache2/sites-enabled/ 2>/dev/null || ls -la /etc/httpd/conf.d/ 2>/dev/null || true
echo "--- Enabled modules ---"
apache2ctl -M 2>/dev/null || httpd -M 2>/dev/null || true
echo "--- Apache ports ---"
cat /etc/apache2/ports.conf 2>/dev/null || true

divider "POSTGRESQL"
psql --version 2>/dev/null || echo "psql not installed"
pg_lsclusters 2>/dev/null || true
systemctl status postgresql 2>/dev/null | head -15 || service postgresql status 2>/dev/null || true
echo "--- pg_hba.conf (non-comment lines) ---"
find /etc/postgresql -name pg_hba.conf -exec grep -v '^#' {} \; 2>/dev/null || true
echo "--- Databases ---"
sudo -u postgres psql -c "\l" 2>/dev/null || true
echo "--- Roles ---"
sudo -u postgres psql -c "\du" 2>/dev/null || true
echo "--- listen_addresses ---"
find /etc/postgresql -name postgresql.conf -exec grep listen_addresses {} \; 2>/dev/null || true

divider "COMPOSER"
composer --version 2>/dev/null || echo "Composer not installed"

divider "EXISTING WEB APPS"
echo "--- /var/www contents ---"
ls -la /var/www/ 2>/dev/null || true
echo "--- /var/www/html contents ---"
ls -la /var/www/html/ 2>/dev/null || true

divider "FIREWALL"
ufw status verbose 2>/dev/null || iptables -L -n 2>/dev/null | head -30 || true

divider "LISTENING PORTS"
ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null || true

divider "SYSTEMD SERVICES (running)"
systemctl list-units --type=service --state=running 2>/dev/null | head -40 || true

divider "DOCKER"
docker --version 2>/dev/null || echo "Docker not installed"
docker ps -a 2>/dev/null || true

divider "ENV VARS (non-sensitive)"
env | grep -iE '(APP_|DB_|PG|PHP|APACHE|HOME|PATH|LANG|USER|SHELL)' 2>/dev/null || true

echo ""
echo "======== DISCOVERY COMPLETE (192.168.1.66) ========"
