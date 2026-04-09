#!/usr/bin/env bash
# ============================================================
# OCR Platform — Application Server Setup (192.168.1.66)
# Run as: sudo bash setup.sh
# ============================================================
set -euo pipefail

REPO_URL="https://github.com/nkosinathil/ocr.git"
BRANCH="cursor/ocr-platform-871c"
INSTALL_DIR="/var/www/ocr-platform"
DB_NAME="ocr_platform"
DB_USER="ocr_app"
DB_PASS="ocr_secure_password_2024"

echo "=========================================="
echo "  OCR Platform — App Server Setup"
echo "  Server: 192.168.1.66 (githemba)"
echo "=========================================="

# ---- 1. Install PostgreSQL ----
echo ""
echo "==> Step 1: Installing PostgreSQL..."
if ! command -v psql &>/dev/null; then
    apt-get update -qq
    apt-get install -y -qq postgresql postgresql-contrib
    systemctl enable postgresql
    systemctl start postgresql
    echo "    PostgreSQL installed and started."
else
    echo "    PostgreSQL already installed."
fi

# ---- 2. Create Database & User ----
echo ""
echo "==> Step 2: Creating database and user..."
sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';"

sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1 || {
    sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"
    sudo -u postgres psql -d "${DB_NAME}" -c "GRANT ALL ON SCHEMA public TO ${DB_USER};"
}
echo "    Database '${DB_NAME}' and user '${DB_USER}' ready."

# ---- 3. Allow remote PostgreSQL connections from Python server ----
echo ""
echo "==> Step 3: Configuring PostgreSQL for remote access from 192.168.1.90..."
PG_HBA=$(find /etc/postgresql -name pg_hba.conf | head -1)
PG_CONF=$(find /etc/postgresql -name postgresql.conf | head -1)

if ! grep -q "192.168.1.90" "$PG_HBA" 2>/dev/null; then
    echo "host    ${DB_NAME}    ${DB_USER}    192.168.1.90/32    scram-sha-256" >> "$PG_HBA"
    echo "    Added pg_hba.conf entry for 192.168.1.90."
fi

if grep -q "^#listen_addresses" "$PG_CONF"; then
    sed -i "s/^#listen_addresses.*/listen_addresses = 'localhost,192.168.1.66'/" "$PG_CONF"
elif grep -q "^listen_addresses" "$PG_CONF"; then
    sed -i "s/^listen_addresses.*/listen_addresses = 'localhost,192.168.1.66'/" "$PG_CONF"
else
    echo "listen_addresses = 'localhost,192.168.1.66'" >> "$PG_CONF"
fi

systemctl restart postgresql
echo "    PostgreSQL configured for remote access."

# ---- 4. Apply Schema ----
echo ""
echo "==> Step 4: Applying database schema..."
if [ -d "${INSTALL_DIR}" ]; then
    sudo -u postgres psql -d "${DB_NAME}" -f "${INSTALL_DIR}/database/schema.sql"
else
    echo "    Will apply after clone (step 6)."
fi

# ---- 5. Install Composer ----
echo ""
echo "==> Step 5: Installing Composer..."
if ! command -v composer &>/dev/null; then
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
    echo "    Composer installed."
else
    echo "    Composer already installed."
fi

# ---- 6. Clone Repo & Deploy PHP App ----
echo ""
echo "==> Step 6: Deploying PHP application..."
if [ -d "${INSTALL_DIR}" ]; then
    cd "${INSTALL_DIR}"
    git fetch origin "${BRANCH}"
    git checkout "${BRANCH}"
    git pull origin "${BRANCH}"
else
    git clone -b "${BRANCH}" "${REPO_URL}" "${INSTALL_DIR}"
fi

cd "${INSTALL_DIR}/php-app"
composer install --no-dev --optimize-autoloader 2>/dev/null || composer dump-autoload --optimize

# Apply schema if not done above
echo "    Applying database schema..."
sudo -u postgres psql -d "${DB_NAME}" -f "${INSTALL_DIR}/database/schema.sql" 2>/dev/null || true

chown -R www-data:www-data "${INSTALL_DIR}"
echo "    PHP app deployed to ${INSTALL_DIR}/php-app."

# ---- 7. Configure php.ini upload limits ----
echo ""
echo "==> Step 7: Configuring PHP upload limits..."
for ini in /etc/php/8.1/fpm/php.ini /etc/php/8.1/apache2/php.ini /etc/php/8.1/cli/php.ini; do
    if [ -f "$ini" ]; then
        sed -i 's/^upload_max_filesize.*/upload_max_filesize = 100M/' "$ini"
        sed -i 's/^post_max_size.*/post_max_size = 105M/' "$ini"
        sed -i 's/^max_execution_time.*/max_execution_time = 300/' "$ini"
        sed -i 's/^memory_limit.*/memory_limit = 256M/' "$ini"
    fi
done
systemctl restart php8.1-fpm 2>/dev/null || true
echo "    PHP upload limits set (100MB)."

# ---- 8. Configure Apache VHost ----
echo ""
echo "==> Step 8: Configuring Apache virtual host..."
cat > /etc/apache2/sites-available/ocr-platform.conf << 'VHOST'
<VirtualHost *:80>
    ServerName 192.168.1.66
    ServerAlias ocr.local

    DocumentRoot /var/www/ocr-platform/php-app/public
    DirectoryIndex index.php index.html

    <Directory /var/www/ocr-platform/php-app/public>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    LimitRequestBody 104857600

    ErrorLog ${APACHE_LOG_DIR}/ocr-platform-error.log
    CustomLog ${APACHE_LOG_DIR}/ocr-platform-access.log combined

    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-XSS-Protection "1; mode=block"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"

    <FilesMatch \.php$>
        SetHandler "proxy:unix:/run/php/php8.1-fpm.sock|fcgi://localhost/"
    </FilesMatch>

    <FilesMatch "^\.">
        Require all denied
    </FilesMatch>

    ServerSignature Off
    Timeout 300
</VirtualHost>
VHOST

a2ensite ocr-platform 2>/dev/null || true
a2enmod rewrite headers proxy_fcgi 2>/dev/null || true
apache2ctl configtest
systemctl reload apache2
echo "    Apache configured for OCR Platform."

# ---- 9. Firewall ----
echo ""
echo "==> Step 9: Opening firewall port 5432 for Python server..."
if command -v ufw &>/dev/null; then
    ufw allow from 192.168.1.90 to any port 5432 proto tcp 2>/dev/null || true
    ufw --force enable 2>/dev/null || true
fi

echo ""
echo "=========================================="
echo "  App Server Setup Complete!"
echo "=========================================="
echo ""
echo "  Next steps:"
echo "  1. Run register-keycloak-client.sh on SSO server (192.168.1.59)"
echo "  2. Copy the client secret to: ${INSTALL_DIR}/php-app/.env"
echo "     Set: SSO_CLIENT_SECRET=<secret from Keycloak>"
echo "  3. Setup Python server (192.168.1.90)"
echo ""
echo "  Test: curl http://192.168.1.66/health 2>/dev/null || echo 'check Apache'"
echo "  DB:   sudo -u postgres psql -d ${DB_NAME} -c '\\dt'"
echo "=========================================="
