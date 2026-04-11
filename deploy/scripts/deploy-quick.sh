#!/bin/bash
# ============================================================================
# Quick Deployment Script for Non-Root Users
# ============================================================================
# This is a convenience wrapper that prompts for usernames and runs deployment
# ============================================================================

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}==================================================================${NC}"
echo -e "${CYAN}MXA OCR - Quick Deployment Setup${NC}"
echo -e "${CYAN}==================================================================${NC}"
echo ""
echo -e "${YELLOW}This script will deploy MXA OCR using your SSH credentials${NC}"
echo ""

# Server IPs (can be customized)
APP_SERVER="${APP_SERVER:-192.168.1.66}"
PYTHON_SERVER="${PYTHON_SERVER:-192.168.1.90}"
SSO_SERVER="${SSO_SERVER:-192.168.1.59}"

echo -e "${BLUE}Target Servers:${NC}"
echo -e "  App Server (PHP/PostgreSQL): $APP_SERVER"
echo -e "  Python Server (OCR Backend): $PYTHON_SERVER"
echo -e "  SSO Server (Keycloak):       $SSO_SERVER"
echo ""

# Prompt for usernames
echo -e "${YELLOW}Enter your SSH username for each server:${NC}"
echo ""

read -p "Username for App Server [$USER]: " SSH_USER_APP
SSH_USER_APP="${SSH_USER_APP:-$USER}"

read -p "Username for Python Server [$USER]: " SSH_USER_PYTHON
SSH_USER_PYTHON="${SSH_USER_PYTHON:-$USER}"

read -p "Username for SSO Server [$USER]: " SSH_USER_SSO
SSH_USER_SSO="${SSH_USER_SSO:-$USER}"

echo ""
echo -e "${GREEN}Configuration:${NC}"
echo -e "  App Server:    ${SSH_USER_APP}@${APP_SERVER}"
echo -e "  Python Server: ${SSH_USER_PYTHON}@${PYTHON_SERVER}"
echo -e "  SSO Server:    ${SSH_USER_SSO}@${SSO_SERVER}"
echo ""

# Export environment variables
export APP_SERVER
export PYTHON_SERVER
export SSO_SERVER
export SSH_USER_APP
export SSH_USER_PYTHON
export SSH_USER_SSO

# Run deployment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/deploy-nonroot.sh"
