#!/usr/bin/env bash
# ============================================================
# Discovery Script — SSO Server (192.168.1.59)
# Run as: sudo bash discover-sso-server.sh
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

divider "USERS & GROUPS (system)"
echo "--- System users with shells ---"
grep -vE '(nologin|false)$' /etc/passwd
echo ""
echo "--- All groups ---"
cat /etc/group

# ---- Detect SSO platform ----
divider "SSO PLATFORM DETECTION"

echo "--- Checking for Keycloak ---"
find / -maxdepth 5 -name "keycloak*" -type d 2>/dev/null | head -10 || true
ps aux | grep -i keycloak | grep -v grep || echo "No Keycloak process"
docker ps -a 2>/dev/null | grep -i keycloak || echo "No Keycloak container"

echo "--- Checking for Authentik ---"
docker ps -a 2>/dev/null | grep -i authentik || echo "No Authentik container"
find / -maxdepth 5 -name "authentik*" 2>/dev/null | head -10 || true

echo "--- Checking for FreeIPA ---"
ipa --version 2>/dev/null || echo "FreeIPA CLI not found"
systemctl status ipa 2>/dev/null | head -10 || true

echo "--- Checking for OpenLDAP / LDAP ---"
slapd -V 2>/dev/null || echo "slapd not found"
ldapsearch -x -H ldap://localhost -b "" -s base namingContexts 2>/dev/null || echo "LDAP not responding on localhost"
systemctl status slapd 2>/dev/null | head -10 || true

echo "--- Checking for Authelia ---"
docker ps -a 2>/dev/null | grep -i authelia || true
find / -maxdepth 4 -name "authelia*" 2>/dev/null | head -5 || true

echo "--- Checking for Dex / OAuth2-Proxy ---"
find / -maxdepth 4 -name "dex*" -o -name "oauth2*proxy*" 2>/dev/null | head -5 || true

echo "--- Checking for custom PHP/Node SSO ---"
ls -la /var/www/ 2>/dev/null || true
ls -la /var/www/html/ 2>/dev/null || true
find /var/www /opt /srv -maxdepth 3 -name "*.php" 2>/dev/null | head -20 || true
find /var/www /opt /srv -maxdepth 3 -name "package.json" 2>/dev/null | head -10 || true

divider "WEB SERVER"
apache2 -v 2>/dev/null || httpd -v 2>/dev/null || echo "Apache not found"
nginx -v 2>/dev/null || echo "Nginx not found"
echo "--- Enabled sites ---"
ls -la /etc/apache2/sites-enabled/ 2>/dev/null || true
ls -la /etc/nginx/sites-enabled/ 2>/dev/null || ls -la /etc/nginx/conf.d/ 2>/dev/null || true

divider "DOCKER"
docker --version 2>/dev/null || echo "Docker not installed"
echo "--- All containers ---"
docker ps -a 2>/dev/null || true
echo "--- Docker compose files ---"
find / -maxdepth 5 -name "docker-compose*.yml" -o -name "docker-compose*.yaml" -o -name "compose*.yml" 2>/dev/null | head -10 || true

divider "DATABASES"
echo "--- PostgreSQL ---"
psql --version 2>/dev/null || echo "psql not installed"
systemctl status postgresql 2>/dev/null | head -10 || true
sudo -u postgres psql -c "\l" 2>/dev/null || true
sudo -u postgres psql -c "\du" 2>/dev/null || true

echo "--- MySQL/MariaDB ---"
mysql --version 2>/dev/null || echo "mysql not installed"
systemctl status mysql 2>/dev/null | head -10 || systemctl status mariadb 2>/dev/null | head -10 || true

echo "--- SQLite databases ---"
find /var /opt /srv /home -maxdepth 4 -name "*.db" -o -name "*.sqlite" -o -name "*.sqlite3" 2>/dev/null | head -10 || true

divider "SSO CONFIGURATION FILES"
echo "--- Keycloak config ---"
find / -maxdepth 6 -name "keycloak.conf" -o -name "standalone.xml" -o -name "realm-export.json" 2>/dev/null | head -10 || true
echo "--- Any OIDC/OAuth config ---"
find /etc /opt /var/www /srv -maxdepth 4 -name "*.conf" -o -name "*.yml" -o -name "*.yaml" -o -name "*.json" -o -name "*.env" 2>/dev/null | xargs grep -li -E '(client_id|client_secret|realm|issuer|authorize|token_endpoint|oidc|oauth)' 2>/dev/null | head -20 || true

divider "SSL / CERTIFICATES"
ls -la /etc/ssl/certs/ssl-cert-snakeoil.pem 2>/dev/null || true
find /etc -maxdepth 4 -name "*.pem" -o -name "*.crt" -o -name "*.key" 2>/dev/null | head -15 || true
certbot certificates 2>/dev/null || echo "certbot not installed / no certs"

divider "LISTENING PORTS"
ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null || true

divider "SYSTEMD SERVICES (running)"
systemctl list-units --type=service --state=running 2>/dev/null | head -50 || true

divider "FIREWALL"
ufw status verbose 2>/dev/null || iptables -L -n 2>/dev/null | head -30 || true

divider "JAVA (for Keycloak/other JVM SSO)"
java -version 2>&1 || echo "Java not installed"

divider "NODE.JS (for JS-based SSO)"
node --version 2>/dev/null || echo "Node.js not installed"
npm --version 2>/dev/null || true

divider "PYTHON (for Python-based SSO)"
python3 --version 2>/dev/null || echo "Python3 not installed"

divider "RECENT LOGS (auth-related)"
journalctl -u keycloak --no-pager -n 20 2>/dev/null || true
journalctl -u apache2 --no-pager -n 10 2>/dev/null || true
journalctl -u nginx --no-pager -n 10 2>/dev/null || true

echo ""
echo "======== DISCOVERY COMPLETE (192.168.1.59) ========"
