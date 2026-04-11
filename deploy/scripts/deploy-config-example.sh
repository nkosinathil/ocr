#!/bin/bash
# ============================================================================
# Example Deployment Configuration
# ============================================================================
# Copy this file and customize it for your environment
# Save as: deploy-config-local.sh
# Then run: source deploy-config-local.sh && bash deploy-nonroot.sh
# ============================================================================

# CUSTOMIZE THESE VALUES
# Replace with your actual SSH usernames for each server

# Username for App Server (192.168.1.66)
export SSH_USER_APP="yourname"

# Username for Python Server (192.168.1.90)
export SSH_USER_PYTHON="yourname"

# Username for SSO Server (192.168.1.59)
export SSH_USER_SSO="yourname"

# ============================================================================
# Optional: Override server IPs if different
# ============================================================================
# export APP_SERVER="192.168.1.66"
# export PYTHON_SERVER="192.168.1.90"
# export SSO_SERVER="192.168.1.59"

# ============================================================================
# Optional: Override repository settings
# ============================================================================
# export REPO_URL="https://github.com/yourorg/yourrepo.git"
# export BRANCH="main"

echo "Configuration loaded:"
echo "  App Server:    $SSH_USER_APP@${APP_SERVER:-192.168.1.66}"
echo "  Python Server: $SSH_USER_PYTHON@${PYTHON_SERVER:-192.168.1.90}"
echo "  SSO Server:    $SSH_USER_SSO@${SSO_SERVER:-192.168.1.59}"
echo ""
echo "To deploy, run: bash deploy-nonroot.sh"
