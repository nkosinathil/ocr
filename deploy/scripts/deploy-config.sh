#!/bin/bash
# ============================================================================
# MXA OCR - Deployment Configuration
# ============================================================================
# This file contains server and SSH configuration for deployment
# Copy this file and customize it for your environment
# ============================================================================

# Server IP addresses
export APP_SERVER="192.168.1.66"
export PYTHON_SERVER="192.168.1.90"
export SSO_SERVER="192.168.1.59"

# SSH usernames for each server (customize these)
# If a user is not specified, it will default to the value of SSH_USER
export SSH_USER_APP="${SSH_USER_APP:-yourusername}"
export SSH_USER_PYTHON="${SSH_USER_PYTHON:-yourusername}"
export SSH_USER_SSO="${SSH_USER_SSO:-yourusername}"

# Repository configuration
export REPO_URL="${REPO_URL:-https://github.com/nkosinathil/ocr.git}"
export BRANCH="${BRANCH:-main}"

# Deployment directories
export APP_SERVER_DIR="/var/www/mxa-ocr-app"
export PYTHON_SERVER_DIR="/opt/apps/mxa-ocr"

# ============================================================================
# Usage Instructions
# ============================================================================
# 
# 1. Copy this file to deploy-config-local.sh:
#    cp deploy-config.sh deploy-config-local.sh
#
# 2. Edit deploy-config-local.sh with your specific usernames:
#    nano deploy-config-local.sh
#
# 3. Source the config file before running deployment:
#    source deploy-config-local.sh
#    bash deploy-nonroot.sh
#
# OR set environment variables directly:
#    SSH_USER_APP=john SSH_USER_PYTHON=jane SSH_USER_SSO=admin bash deploy-nonroot.sh
#
# ============================================================================
# Example Configurations
# ============================================================================
#
# Example 1: Same username on all servers
#   export SSH_USER_APP="john"
#   export SSH_USER_PYTHON="john"
#   export SSH_USER_SSO="john"
#
# Example 2: Different usernames per server
#   export SSH_USER_APP="appuser"
#   export SSH_USER_PYTHON="pythonuser"
#   export SSH_USER_SSO="ssoadmin"
#
# Example 3: Using your current Windows username
#   export SSH_USER_APP="nkosinathi"
#   export SSH_USER_PYTHON="nkosinathi"
#   export SSH_USER_SSO="administrator"
#
# ============================================================================
# Important Notes
# ============================================================================
#
# - Your SSH users must have sudo privileges on their respective servers
# - Passwordless sudo is recommended (configure with visudo)
# - SSH key authentication should be set up for all servers
# - Users need permissions to write to deployment directories
#
# ============================================================================
