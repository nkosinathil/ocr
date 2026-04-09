#!/usr/bin/env bash
# ============================================================
# Register OCR Platform OIDC Client in Keycloak (gint realm)
# Run on: 192.168.1.59 (SSO Server) as ssoadmin
# ============================================================
set -euo pipefail

KEYCLOAK_URL="http://127.0.0.1:8080"
REALM="gint"
ADMIN_USER="admin"
ADMIN_PASS="5ucc3SS!@#s"

OCR_CLIENT_ID="gint-ocr-platform"
OCR_CLIENT_NAME="GI OCR Platform"
PHP_SERVER="http://192.168.1.66"

echo "==> Obtaining admin access token..."
TOKEN=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" \
    -d "username=${ADMIN_USER}" \
    -d "password=${ADMIN_PASS}" \
    -H "Content-Type: application/x-www-form-urlencoded" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

if [ -z "$TOKEN" ]; then
    echo "ERROR: Failed to obtain admin token"
    exit 1
fi
echo "    Admin token obtained."

echo "==> Checking if client '${OCR_CLIENT_ID}' already exists..."
EXISTING=$(curl -s -H "Authorization: Bearer ${TOKEN}" \
    "${KEYCLOAK_URL}/admin/realms/${REALM}/clients?clientId=${OCR_CLIENT_ID}")

CLIENT_EXISTS=$(echo "$EXISTING" | python3 -c "import sys,json; data=json.load(sys.stdin); print('yes' if len(data)>0 else 'no')" 2>/dev/null || echo "no")

if [ "$CLIENT_EXISTS" = "yes" ]; then
    echo "    Client already exists. Extracting ID..."
    KC_ID=$(echo "$EXISTING" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['id'])")
    echo "    Keycloak internal ID: ${KC_ID}"
else
    echo "==> Creating OIDC client '${OCR_CLIENT_ID}' in realm '${REALM}'..."
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        "${KEYCLOAK_URL}/admin/realms/${REALM}/clients" \
        -d '{
            "clientId": "'"${OCR_CLIENT_ID}"'",
            "name": "'"${OCR_CLIENT_NAME}"'",
            "enabled": true,
            "protocol": "openid-connect",
            "publicClient": false,
            "standardFlowEnabled": true,
            "directAccessGrantsEnabled": false,
            "serviceAccountsEnabled": true,
            "authorizationServicesEnabled": false,
            "redirectUris": [
                "'"${PHP_SERVER}"'/auth/callback",
                "'"${PHP_SERVER}"'/*"
            ],
            "webOrigins": [
                "'"${PHP_SERVER}"'"
            ],
            "baseUrl": "'"${PHP_SERVER}"'",
            "rootUrl": "'"${PHP_SERVER}"'",
            "attributes": {
                "post.logout.redirect.uris": "'"${PHP_SERVER}"'/auth/logout"
            }
        }')

    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    if [ "$HTTP_CODE" = "201" ]; then
        echo "    Client created successfully."
    else
        echo "ERROR: Failed to create client (HTTP ${HTTP_CODE})"
        echo "$RESPONSE" | head -1
        exit 1
    fi

    EXISTING=$(curl -s -H "Authorization: Bearer ${TOKEN}" \
        "${KEYCLOAK_URL}/admin/realms/${REALM}/clients?clientId=${OCR_CLIENT_ID}")
    KC_ID=$(echo "$EXISTING" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['id'])")
fi

echo "==> Retrieving client secret..."
SECRET_RESPONSE=$(curl -s -H "Authorization: Bearer ${TOKEN}" \
    "${KEYCLOAK_URL}/admin/realms/${REALM}/clients/${KC_ID}/client-secret")

CLIENT_SECRET=$(echo "$SECRET_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['value'])")

echo ""
echo "============================================"
echo "  Keycloak Client Registration Complete"
echo "============================================"
echo ""
echo "  Client ID:     ${OCR_CLIENT_ID}"
echo "  Client Secret:  ${CLIENT_SECRET}"
echo "  Realm:          ${REALM}"
echo ""
echo "  OIDC Endpoints:"
echo "    Auth:       ${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/auth"
echo "    Token:      ${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token"
echo "    UserInfo:   ${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/userinfo"
echo "    Logout:     ${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/logout"
echo ""
echo "  UPDATE the PHP app .env file on 192.168.1.66 with:"
echo "    SSO_CLIENT_SECRET=${CLIENT_SECRET}"
echo ""
echo "============================================"
