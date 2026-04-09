#!/usr/bin/env bash
# ============================================================
# Deep Discovery — SSO Server / Keycloak (192.168.1.59)
# Run as: sudo bash discover-sso-deep.sh
# ============================================================
set -euo pipefail

divider() { echo ""; echo "======== $1 ========"; }

divider "KEYCLOAK INSTALLATION"
echo "--- Keycloak directory ---"
ls -la /opt/keycloak/ 2>/dev/null || true
echo "--- Keycloak version ---"
cat /opt/keycloak/version.txt 2>/dev/null || true
/opt/keycloak/bin/kc.sh --version 2>/dev/null || true
ls /opt/keycloak/lib/lib/main/org.keycloak.keycloak-server-spi-*.jar 2>/dev/null | head -3 || true

divider "KEYCLOAK CONF"
echo "--- /opt/keycloak/conf/keycloak.conf ---"
cat /opt/keycloak/conf/keycloak.conf 2>/dev/null || true

divider "KEYCLOAK SYSTEMD SERVICE"
cat /etc/systemd/system/keycloak.service 2>/dev/null || systemctl cat keycloak 2>/dev/null || true

divider "NGINX CONFIG (Keycloak reverse proxy)"
echo "--- sites-available/keycloak ---"
cat /etc/nginx/sites-available/keycloak 2>/dev/null || true
echo "--- nginx.conf ---"
cat /etc/nginx/nginx.conf 2>/dev/null | head -60 || true

divider "POSTGRESQL — KEYCLOAK DATABASE"
echo "--- Tables in keycloak DB ---"
sudo -u postgres psql -d keycloak -c "\dt" 2>/dev/null || true

divider "KEYCLOAK REALMS"
sudo -u postgres psql -d keycloak -c "SELECT id, name, enabled, display_name FROM realm ORDER BY name;" 2>/dev/null || true

divider "KEYCLOAK CLIENTS (all realms)"
sudo -u postgres psql -d keycloak -c "
    SELECT c.client_id, c.name, c.enabled, c.protocol, c.public_client, c.secret,
           c.base_url, c.root_url, r.name as realm_name
    FROM client c
    JOIN realm r ON c.realm_id = r.id
    WHERE c.client_id NOT LIKE 'account%'
      AND c.client_id NOT LIKE 'admin-cli%'
      AND c.client_id NOT LIKE 'broker%'
      AND c.client_id NOT LIKE 'realm-management%'
      AND c.client_id NOT LIKE 'security-admin%'
    ORDER BY r.name, c.client_id;
" 2>/dev/null || true

divider "KEYCLOAK REDIRECT URIS (per client)"
sudo -u postgres psql -d keycloak -c "
    SELECT c.client_id, r.name as realm_name, ru.value as redirect_uri
    FROM redirect_uris ru
    JOIN client c ON ru.client_id = c.id
    JOIN realm r ON c.realm_id = r.id
    WHERE c.client_id NOT LIKE 'account%'
      AND c.client_id NOT LIKE 'admin-cli%'
    ORDER BY r.name, c.client_id;
" 2>/dev/null || true

divider "KEYCLOAK USERS (all realms)"
sudo -u postgres psql -d keycloak -c "
    SELECT ue.id, ue.username, ue.email, ue.first_name, ue.last_name,
           ue.enabled, ue.email_verified, r.name as realm_name, ue.created_timestamp
    FROM user_entity ue
    JOIN realm r ON ue.realm_id = r.id
    ORDER BY r.name, ue.username;
" 2>/dev/null || true

divider "KEYCLOAK GROUPS"
sudo -u postgres psql -d keycloak -c "
    SELECT kg.id, kg.name, r.name as realm_name, kg.parent_group
    FROM keycloak_group kg
    JOIN realm r ON kg.realm_id = r.id
    ORDER BY r.name, kg.name;
" 2>/dev/null || true

divider "KEYCLOAK ROLES (realm-level)"
sudo -u postgres psql -d keycloak -c "
    SELECT kr.id, kr.name, kr.description, r.name as realm_name
    FROM keycloak_role kr
    JOIN realm r ON kr.realm_id = r.id
    WHERE kr.client_realm_constraint = r.id
    ORDER BY r.name, kr.name;
" 2>/dev/null || true

divider "KEYCLOAK USER-ROLE MAPPINGS"
sudo -u postgres psql -d keycloak -c "
    SELECT ue.username, kr.name as role_name, r.name as realm_name
    FROM user_role_mapping urm
    JOIN user_entity ue ON urm.user_id = ue.id
    JOIN keycloak_role kr ON urm.role_id = kr.id
    JOIN realm r ON ue.realm_id = r.id
    ORDER BY r.name, ue.username;
" 2>/dev/null || true

divider "KEYCLOAK USER-GROUP MAPPINGS"
sudo -u postgres psql -d keycloak -c "
    SELECT ue.username, kg.name as group_name, r.name as realm_name
    FROM user_group_membership ugm
    JOIN user_entity ue ON ugm.user_id = ue.id
    JOIN keycloak_group kg ON ugm.group_id = kg.id
    JOIN realm r ON ue.realm_id = r.id
    ORDER BY r.name, ue.username;
" 2>/dev/null || true

divider "KEYCLOAK IDENTITY PROVIDERS"
sudo -u postgres psql -d keycloak -c "
    SELECT idp.internal_id, idp.provider_id, idp.provider_alias, idp.enabled, r.name as realm_name
    FROM identity_provider idp
    JOIN realm r ON idp.realm_id = r.id
    ORDER BY r.name;
" 2>/dev/null || true

divider "KEYCLOAK CLIENT SCOPES"
sudo -u postgres psql -d keycloak -c "
    SELECT cs.id, cs.name, cs.protocol, cs.description, r.name as realm_name
    FROM client_scope cs
    JOIN realm r ON cs.realm_id = r.id
    ORDER BY r.name, cs.name;
" 2>/dev/null || true

divider "KEYCLOAK ADMIN URL"
echo "Keycloak should be accessible at:"
echo "  - Direct: http://192.168.1.59:8080"
echo "  - Via Nginx: http://192.168.1.59"
echo ""
echo "--- Test connectivity ---"
curl -s -o /dev/null -w "HTTP %{http_code}" http://127.0.0.1:8080/realms/master/.well-known/openid-configuration 2>/dev/null || echo "Cannot reach Keycloak on 8080"
echo ""
curl -s http://127.0.0.1:8080/realms/master/.well-known/openid-configuration 2>/dev/null | python3 -m json.tool 2>/dev/null || true

divider "ALL REALMS OIDC ENDPOINTS"
for realm in $(sudo -u postgres psql -d keycloak -t -c "SELECT name FROM realm WHERE enabled = true;" 2>/dev/null | tr -d ' '); do
    if [ -n "$realm" ]; then
        echo "--- Realm: $realm ---"
        curl -s "http://127.0.0.1:8080/realms/${realm}/.well-known/openid-configuration" 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "Cannot reach realm ${realm}"
        echo ""
    fi
done

echo ""
echo "======== SSO DEEP DISCOVERY COMPLETE ========"
