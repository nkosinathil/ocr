#!/bin/bash
# ============================================================================
# MXA OCR - MinIO Setup Script
# ============================================================================
# This script sets up MinIO object storage for MXA OCR
# Run as: sudo ./setup-minio.sh
# ============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

read_env_value() {
    local env_file="$1"
    local key="$2"
    local value

    value="$(grep -E "^${key}=" "$env_file" | tail -n1 | cut -d'=' -f2- || true)"
    value="${value%\"}"
    value="${value#\"}"
    value="${value%\'}"
    value="${value#\'}"
    echo "$value"
}

echo -e "${GREEN}==================================================================${NC}"
echo -e "${GREEN}MXA OCR - MinIO Setup${NC}"
echo -e "${GREEN}==================================================================${NC}"
echo ""

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE=""

for candidate in \
    "$DEPLOY_ROOT/python-backend/.env" \
    "$DEPLOY_ROOT/current/python-backend/.env"
do
    if [ -f "$candidate" ]; then
        ENV_FILE="$candidate"
        break
    fi
done

ENV_MINIO_ENDPOINT=""
ENV_MINIO_ACCESS_KEY=""
ENV_MINIO_SECRET_KEY=""
ENV_MINIO_BUCKET_INPUT=""
ENV_MINIO_BUCKET_OUTPUT=""
ENV_MINIO_SECURE=""

if [ -n "$ENV_FILE" ]; then
    ENV_MINIO_ENDPOINT="$(read_env_value "$ENV_FILE" "MINIO_ENDPOINT")"
    ENV_MINIO_ACCESS_KEY="$(read_env_value "$ENV_FILE" "MINIO_ACCESS_KEY")"
    ENV_MINIO_SECRET_KEY="$(read_env_value "$ENV_FILE" "MINIO_SECRET_KEY")"
    ENV_MINIO_BUCKET_INPUT="$(read_env_value "$ENV_FILE" "MINIO_BUCKET_INPUT")"
    ENV_MINIO_BUCKET_OUTPUT="$(read_env_value "$ENV_FILE" "MINIO_BUCKET_OUTPUT")"
    ENV_MINIO_SECURE="$(read_env_value "$ENV_FILE" "MINIO_SECURE")"
fi

MINIO_ENDPOINT="${MINIO_ENDPOINT:-${ENV_MINIO_ENDPOINT:-192.168.1.90:9000}}"
MINIO_ACCESS_KEY="${MINIO_ACCESS_KEY:-${ENV_MINIO_ACCESS_KEY:-minio-access-key}}"
MINIO_SECRET_KEY="${MINIO_SECRET_KEY:-${ENV_MINIO_SECRET_KEY:-minio-secret-key}}"
BUCKET_INPUT="${MINIO_BUCKET_INPUT:-${ENV_MINIO_BUCKET_INPUT:-mxa-ocr-input}}"
BUCKET_OUTPUT="${MINIO_BUCKET_OUTPUT:-${ENV_MINIO_BUCKET_OUTPUT:-mxa-ocr-output}}"
MINIO_SECURE="${MINIO_SECURE:-${ENV_MINIO_SECURE:-false}}"

MINIO_PROTOCOL="http"
case "${MINIO_SECURE,,}" in
    true|1|yes) MINIO_PROTOCOL="https" ;;
esac

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo -e "${YELLOW}Run: sudo $0${NC}"
    exit 1
fi

# ============================================================================
# Step 1: Install MinIO Client (mc)
# ============================================================================

echo -e "${YELLOW}Step 1: Installing MinIO Client...${NC}"

if ! command -v mc &>/dev/null; then
    echo -e "${YELLOW}Downloading MinIO Client...${NC}"
    wget -q https://dl.min.io/client/mc/release/linux-amd64/mc -O /usr/local/bin/mc
    chmod +x /usr/local/bin/mc
    echo -e "${GREEN}MinIO Client installed${NC}"
else
    echo -e "${YELLOW}MinIO Client already installed${NC}"
fi

# ============================================================================
# Step 2: Configure MinIO Connection
# ============================================================================

echo -e "${YELLOW}Step 2: Configuring MinIO connection...${NC}"
echo -e "${YELLOW}Using endpoint: ${MINIO_PROTOCOL}://${MINIO_ENDPOINT}${NC}"
if [ -n "$ENV_FILE" ]; then
    echo -e "${YELLOW}Using MinIO settings from: ${ENV_FILE}${NC}"
fi

# Configure alias
if ! mc alias set mxaocr "${MINIO_PROTOCOL}://${MINIO_ENDPOINT}" "${MINIO_ACCESS_KEY}" "${MINIO_SECRET_KEY}"; then
    echo -e "${RED}Failed to configure MinIO alias (mxaocr)${NC}"
    echo -e "${YELLOW}Verify endpoint and credentials. Internal envs usually require MINIO_SECURE=false and a reachable private endpoint.${NC}"
    exit 1
fi

# Test connection
if mc admin info mxaocr &>/dev/null; then
    echo -e "${GREEN}Successfully connected to MinIO${NC}"
else
    echo -e "${RED}Failed to connect to MinIO${NC}"
    echo -e "${YELLOW}Please check MinIO server status and credentials${NC}"
    exit 1
fi

# ============================================================================
# Step 3: Create Buckets
# ============================================================================

echo -e "${YELLOW}Step 3: Creating buckets...${NC}"

# Create input bucket
if mc ls mxaocr/${BUCKET_INPUT} &>/dev/null; then
    echo -e "${YELLOW}Bucket ${BUCKET_INPUT} already exists${NC}"
else
    mc mb mxaocr/${BUCKET_INPUT}
    echo -e "${GREEN}Created bucket: ${BUCKET_INPUT}${NC}"
fi

# Create output bucket
if mc ls mxaocr/${BUCKET_OUTPUT} &>/dev/null; then
    echo -e "${YELLOW}Bucket ${BUCKET_OUTPUT} already exists${NC}"
else
    mc mb mxaocr/${BUCKET_OUTPUT}
    echo -e "${GREEN}Created bucket: ${BUCKET_OUTPUT}${NC}"
fi

# ============================================================================
# Step 4: Set Bucket Policies
# ============================================================================

echo -e "${YELLOW}Step 4: Setting bucket policies...${NC}"

# Input bucket - private (only application can access)
mc anonymous set none mxaocr/${BUCKET_INPUT}
echo -e "${GREEN}Input bucket policy: private${NC}"

# Output bucket - private (results are sensitive)
mc anonymous set none mxaocr/${BUCKET_OUTPUT}
echo -e "${GREEN}Output bucket policy: private${NC}"

# ============================================================================
# Step 5: Create Test File
# ============================================================================

echo -e "${YELLOW}Step 5: Testing bucket access...${NC}"

# Create test file
TEST_FILE="/tmp/mxa-ocr-test.txt"
echo "MXA OCR MinIO Test - $(date)" > ${TEST_FILE}

# Upload test file
mc cp ${TEST_FILE} mxaocr/${BUCKET_INPUT}/test.txt
echo -e "${GREEN}Test file uploaded${NC}"

# Download test file
mc cp mxaocr/${BUCKET_INPUT}/test.txt /tmp/mxa-ocr-test-download.txt
echo -e "${GREEN}Test file downloaded${NC}"

# Remove test files
mc rm mxaocr/${BUCKET_INPUT}/test.txt
rm -f ${TEST_FILE} /tmp/mxa-ocr-test-download.txt
echo -e "${GREEN}Test files cleaned up${NC}"

# ============================================================================
# Step 6: Display Bucket Information
# ============================================================================

echo -e "${YELLOW}Step 6: Bucket information...${NC}"

echo ""
echo -e "${GREEN}Bucket Summary:${NC}"
mc ls mxaocr/

# ============================================================================
# Step 7: Set Lifecycle Policies (Optional)
# ============================================================================

echo -e "${YELLOW}Step 7: Setting lifecycle policies...${NC}"

# Create lifecycle policy for temporary files
cat > /tmp/mxa-ocr-lifecycle.json <<EOF
{
  "Rules": [
    {
      "ID": "DeleteOldInputFiles",
      "Status": "Enabled",
      "Filter": {
        "Prefix": ""
      },
      "Expiration": {
        "Days": 30
      }
    }
  ]
}
EOF

# Apply lifecycle policy to input bucket (files older than 30 days are deleted)
if mc ilm import mxaocr/${BUCKET_INPUT} < /tmp/mxa-ocr-lifecycle.json 2>/dev/null; then
    echo -e "${GREEN}Lifecycle policy applied to input bucket${NC}"
else
    echo -e "${YELLOW}Could not apply lifecycle policy (may not be supported)${NC}"
fi

rm -f /tmp/mxa-ocr-lifecycle.json

echo ""
echo -e "${GREEN}==================================================================${NC}"
echo -e "${GREEN}MinIO setup completed successfully!${NC}"
echo -e "${GREEN}==================================================================${NC}"
echo ""
echo -e "MinIO Endpoint:  ${GREEN}${MINIO_ENDPOINT}${NC}"
echo -e "Access Key:      ${GREEN}${MINIO_ACCESS_KEY}${NC}"
echo -e "Secret Key:      ${YELLOW}[configured]${NC}"
echo -e "Input Bucket:    ${GREEN}${BUCKET_INPUT}${NC}"
echo -e "Output Bucket:   ${GREEN}${BUCKET_OUTPUT}${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Update .env files with MinIO credentials"
echo -e "2. Test upload from application"
echo -e "3. Monitor bucket usage: mc admin info mxaocr"
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo -e "  List buckets:       mc ls mxaocr/"
echo -e "  List bucket files:  mc ls mxaocr/${BUCKET_INPUT}/"
echo -e "  Bucket info:        mc du mxaocr/${BUCKET_INPUT}"
echo -e "  Server info:        mc admin info mxaocr"
echo ""
