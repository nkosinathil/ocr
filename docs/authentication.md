# MXA OCR - Authentication

## Overview

MXA OCR uses Keycloak for authentication via OpenID Connect (OIDC).

## Keycloak Configuration

**Server:** 192.168.1.59:8080  
**Realm:** master (or custom)  
**Client ID:** mxa-ocr-web  
**Protocol:** openid-connect  
**Flow:** Authorization Code Flow

## Authentication Flow

1. User visits application
2. Redirect to Keycloak login
3. User authenticates
4. Keycloak redirects back with code
5. PHP exchanges code for tokens
6. PHP creates/updates user in database
7. Session established

## Roles

- `ocr_admin` - Full administrative access
- `ocr_user` - Submit and view own jobs
- `ocr_viewer` - Read-only access

## Session Management

- Session timeout: 30 minutes idle
- Secure, HttpOnly cookies
- SameSite=Strict

## Token Refresh

Access tokens expire after 5 minutes. PHP automatically refreshes using refresh token.

## Logout

Logout clears local session and redirects to Keycloak logout endpoint.

## Related Documentation
- [Architecture](architecture.md)
- [Configuration](configuration.md)
