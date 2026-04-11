#!/bin/bash
# ============================================================================
# SSH Key Setup Helper Script
# ============================================================================
# This script helps set up SSH keys for deployment
# Especially useful for Windows/Git Bash users
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo -e "${CYAN}==================================================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}==================================================================${NC}"
    echo ""
}

print_step() {
    echo -e "${YELLOW}>>> $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_header "SSH Key Setup for MXA OCR Deployment"

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

# ============================================================================
# Step 1: Check for SSH Key
# ============================================================================

print_header "Step 1: Checking for SSH Key"

SSH_KEY_PATH="$HOME/.ssh/id_rsa"
SSH_PUB_KEY_PATH="$HOME/.ssh/id_rsa.pub"

if [ -f "$SSH_KEY_PATH" ] && [ -f "$SSH_PUB_KEY_PATH" ]; then
    print_success "SSH key pair found at $SSH_KEY_PATH"
else
    print_error "No SSH key found"
    print_step "Generating new SSH key pair..."
    
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N ""
    
    if [ $? -eq 0 ]; then
        print_success "SSH key generated successfully"
    else
        print_error "Failed to generate SSH key"
        exit 1
    fi
fi

# ============================================================================
# Step 2: Start SSH Agent and Add Key
# ============================================================================

print_header "Step 2: Setting up SSH Agent"

# Check if SSH agent is running
if [ -z "$SSH_AUTH_SOCK" ]; then
    print_step "Starting SSH agent..."
    eval "$(ssh-agent -s)"
    
    if [ $? -eq 0 ]; then
        print_success "SSH agent started"
    else
        print_error "Failed to start SSH agent"
        exit 1
    fi
else
    print_success "SSH agent is already running"
fi

# Add the SSH key to the agent
print_step "Adding SSH key to agent..."
ssh-add "$SSH_KEY_PATH" 2>/dev/null

if [ $? -eq 0 ]; then
    print_success "SSH key added to agent"
else
    print_info "Key may already be added or locked"
fi

# List keys in agent
print_step "Keys loaded in SSH agent:"
ssh-add -l 2>/dev/null
echo ""

# ============================================================================
# Step 3: Copy Keys to Servers
# ============================================================================

print_header "Step 3: Copying SSH Keys to Servers"

print_info "You will be prompted for the password for each server"
echo ""

# Copy to App Server
print_step "Copying key to App Server ($SSH_USER_APP@$APP_SERVER)..."
ssh-copy-id -o StrictHostKeyChecking=no "$SSH_USER_APP@$APP_SERVER"

if [ $? -eq 0 ]; then
    print_success "Key copied to App Server"
else
    print_error "Failed to copy key to App Server"
fi

echo ""

# Copy to Python Server
print_step "Copying key to Python Server ($SSH_USER_PYTHON@$PYTHON_SERVER)..."
ssh-copy-id -o StrictHostKeyChecking=no "$SSH_USER_PYTHON@$PYTHON_SERVER"

if [ $? -eq 0 ]; then
    print_success "Key copied to Python Server"
else
    print_error "Failed to copy key to Python Server"
fi

echo ""

# Copy to SSO Server
print_step "Copying key to SSO Server ($SSH_USER_SSO@$SSO_SERVER)..."
ssh-copy-id -o StrictHostKeyChecking=no "$SSH_USER_SSO@$SSO_SERVER"

if [ $? -eq 0 ]; then
    print_success "Key copied to SSO Server"
else
    print_error "Failed to copy key to SSO Server"
fi

echo ""

# ============================================================================
# Step 4: Test Connections
# ============================================================================

print_header "Step 4: Testing SSH Connections"

all_passed=true

# Test App Server
print_step "Testing connection to App Server..."
if ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$SSH_USER_APP@$APP_SERVER" exit 2>/dev/null; then
    print_success "App Server connection works!"
else
    print_error "App Server connection failed"
    all_passed=false
fi

# Test Python Server
print_step "Testing connection to Python Server..."
if ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$SSH_USER_PYTHON@$PYTHON_SERVER" exit 2>/dev/null; then
    print_success "Python Server connection works!"
else
    print_error "Python Server connection failed"
    all_passed=false
fi

# Test SSO Server
print_step "Testing connection to SSO Server..."
if ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$SSH_USER_SSO@$SSO_SERVER" exit 2>/dev/null; then
    print_success "SSO Server connection works!"
else
    print_error "SSO Server connection failed"
    all_passed=false
fi

echo ""

# ============================================================================
# Final Summary
# ============================================================================

print_header "Setup Complete"

if [ "$all_passed" = true ]; then
    print_success "All SSH connections are working!"
    echo ""
    print_info "You can now run the deployment script:"
    echo -e "  ${GREEN}bash deploy-quick.sh${NC}"
    echo ""
    
    # Export variables for use in deployment
    export APP_SERVER
    export PYTHON_SERVER
    export SSO_SERVER
    export SSH_USER_APP
    export SSH_USER_PYTHON
    export SSH_USER_SSO
    
else
    print_error "Some connections failed"
    echo ""
    print_info "Troubleshooting tips:"
    echo -e "  ${BLUE}1.${NC} Make sure the servers are reachable"
    echo -e "  ${BLUE}2.${NC} Verify the usernames are correct"
    echo -e "  ${BLUE}3.${NC} Check firewall settings"
    echo -e "  ${BLUE}4.${NC} Ensure the passwords you entered were correct"
    echo ""
    print_info "For Windows/Git Bash users:"
    echo -e "  ${BLUE}1.${NC} Make sure Git Bash is running as administrator (may be needed)"
    echo -e "  ${BLUE}2.${NC} Try closing and reopening Git Bash to reload SSH agent"
    echo -e "  ${BLUE}3.${NC} Check file permissions on ~/.ssh/id_rsa (should be 600)"
    echo ""
fi
