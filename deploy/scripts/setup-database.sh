#!/bin/bash
# ============================================================================
# MXA OCR - Database Setup Script
# ============================================================================
# This script sets up the PostgreSQL database for MXA OCR
# Run as: sudo -u postgres ./setup-database.sh
# ============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}==================================================================${NC}"
echo -e "${GREEN}MXA OCR - Database Setup${NC}"
echo -e "${GREEN}==================================================================${NC}"
echo ""

# Configuration
DB_NAME="mxa_ocr"
DB_USER="mxa_ocr_user"
DB_PASSWORD="${DB_PASSWORD:-5ucc3SS!@#s}"  # Can be overridden by env var
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Check if running as postgres user
if [ "$(whoami)" != "postgres" ]; then
    echo -e "${RED}Error: This script must be run as the postgres user${NC}"
    echo -e "${YELLOW}Run: sudo -u postgres $0${NC}"
    exit 1
fi

# Step 1: Create database user
echo -e "${YELLOW}Step 1: Creating database user...${NC}"
psql -v ON_ERROR_STOP=1 <<EOF
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = '$DB_USER') THEN
        CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
        RAISE NOTICE 'User $DB_USER created';
    ELSE
        RAISE NOTICE 'User $DB_USER already exists';
    END IF;
END
\$\$;
EOF

# Step 2: Create database
echo -e "${YELLOW}Step 2: Creating database...${NC}"
psql -v ON_ERROR_STOP=1 <<EOF
SELECT 'CREATE DATABASE $DB_NAME OWNER $DB_USER ENCODING ''UTF8'''
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$DB_NAME')\gexec
EOF

# Step 3: Grant privileges
echo -e "${YELLOW}Step 3: Granting privileges...${NC}"
psql -v ON_ERROR_STOP=1 <<EOF
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
EOF

# Step 4: Run schema
echo -e "${YELLOW}Step 4: Running database schema...${NC}"
PGPASSWORD="$DB_PASSWORD" psql -v ON_ERROR_STOP=1 -h 127.0.0.1 -U "$DB_USER" -d "$DB_NAME" -f "$REPO_ROOT/database/schema.sql"

echo ""
echo -e "${GREEN}==================================================================${NC}"
echo -e "${GREEN}Database setup completed successfully!${NC}"
echo -e "${GREEN}==================================================================${NC}"
echo ""
echo -e "Database: ${GREEN}$DB_NAME${NC}"
echo -e "User: ${GREEN}$DB_USER${NC}"
echo -e "Password: ${YELLOW}[configured]${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Update .env files with database credentials"
echo -e "2. Test connection: psql -U $DB_USER -d $DB_NAME -h localhost"
echo ""
