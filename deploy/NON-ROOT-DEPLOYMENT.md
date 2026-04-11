# MXA OCR - Non-Root User Deployment Guide

This guide explains how to deploy MXA OCR when you have SSH access with **non-root users** and **different usernames** on each server.

## Prerequisites

### 1. SSH Access
You need SSH access to all three servers with your own username:
- App Server (192.168.1.66)
- Python Server (192.168.1.90)  
- SSO Server (192.168.1.59)

### 2. SSH Key Authentication
Set up SSH keys for passwordless authentication:

```bash
# If you don't have SSH keys yet
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

# Copy your public key to each server
# Method 1: Using ssh-copy-id (Linux/Mac/Git Bash)
cat ~/.ssh/id_rsa.pub | ssh username@192.168.1.66 "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

cat ~/.ssh/id_rsa.pub | ssh username@192.168.1.90 "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

cat ~/.ssh/id_rsa.pub | ssh username@192.168.1.59 "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

# Method 2: Manual (if above doesn't work)
# 1. Copy your public key content:
cat ~/.ssh/id_rsa.pub

# 2. SSH to each server and paste the key:
ssh username@192.168.1.66
mkdir -p ~/.ssh && chmod 700 ~/.ssh
nano ~/.ssh/authorized_keys  # Paste your public key here
chmod 600 ~/.ssh/authorized_keys
exit

# 3. Test passwordless login:
ssh username@192.168.1.66 "echo 'Success!'"
```

### 3. Sudo Access
Your user account must have sudo privileges on each server:

```bash
# Test sudo access (on each server)
ssh username@192.168.1.66 "sudo -v"
```

If you don't have sudo access, ask your system administrator to add your user to the sudo group:
```bash
# On the server (as root or admin):
usermod -aG sudo username
```

### 4. Passwordless Sudo (Recommended)
To avoid typing your password repeatedly during deployment:

```bash
# On each server, run:
sudo visudo

# Add this line (replace 'username' with your actual username):
username ALL=(ALL) NOPASSWD:ALL

# Save and exit (Ctrl+X, then Y, then Enter)
```

## Deployment Methods

### Method 1: Quick Interactive Deployment (Easiest)

This method prompts you for usernames interactively:

```bash
cd deploy/scripts
bash deploy-quick.sh
```

You'll be prompted to enter your username for each server. Just press Enter to use your current username.

### Method 2: Environment Variables (Scripting-Friendly)

Set environment variables before running deployment:

```bash
cd deploy/scripts

# Set your usernames for each server
export SSH_USER_APP="john"
export SSH_USER_PYTHON="john"
export SSH_USER_SSO="administrator"

# Run deployment
bash deploy-nonroot.sh
```

### Method 3: Configuration File (Reusable)

Create a configuration file for repeated deployments:

```bash
cd deploy/scripts

# Copy the config template
cp deploy-config.sh deploy-config-local.sh

# Edit with your usernames
nano deploy-config-local.sh
```

Example `deploy-config-local.sh`:
```bash
export SSH_USER_APP="john"
export SSH_USER_PYTHON="jane"
export SSH_USER_SSO="administrator"
```

Then run:
```bash
source deploy-config-local.sh
bash deploy-nonroot.sh
```

### Method 4: One-Line Deployment

For quick deployments, set variables inline:

```bash
cd deploy/scripts
SSH_USER_APP=john SSH_USER_PYTHON=jane SSH_USER_SSO=admin bash deploy-nonroot.sh
```

## Command-Line Examples

### Example 1: Same Username on All Servers

If you use the same username (e.g., "john") on all three servers:

```bash
cd deploy/scripts
export SSH_USER_APP="john"
export SSH_USER_PYTHON="john"
export SSH_USER_SSO="john"
bash deploy-nonroot.sh
```

Or simply:
```bash
cd deploy/scripts
bash deploy-quick.sh
# When prompted, enter "john" for all servers
```

### Example 2: Different Usernames Per Server

If you have different usernames on each server:

```bash
cd deploy/scripts
SSH_USER_APP=appuser SSH_USER_PYTHON=pythonuser SSH_USER_SSO=ssoadmin bash deploy-nonroot.sh
```

### Example 3: Windows Git Bash

From Git Bash on Windows:

```bash
# Navigate to your repository
cd ~/OneDrive/Documents/deployment/ocr/deploy/scripts

# Run deployment with your usernames
SSH_USER_APP=nkosinathi SSH_USER_PYTHON=nkosinathi SSH_USER_SSO=administrator bash deploy-nonroot.sh
```

## What the Script Does

The deployment script will:

1. ✅ Verify SSH connections to all servers with your credentials
2. ✅ Check sudo access on each server
3. ✅ Create deployment archive from your repository
4. ✅ Upload code to servers using your SSH credentials
5. ✅ Run installation scripts with `sudo` where needed
6. ✅ Setup PostgreSQL database
7. ✅ Deploy PHP application
8. ✅ Deploy Python backend
9. ✅ Configure MinIO buckets
10. ✅ Start systemd services
11. ✅ Validate deployment

## Troubleshooting

### Problem: SSH Connection Failed

```bash
# Test SSH connection manually
ssh username@192.168.1.66 "echo 'Success'"

# If it fails, check:
# 1. Is your username correct?
# 2. Are SSH keys set up?
# 3. Can you SSH with password?
ssh username@192.168.1.66
```

### Problem: Sudo Permission Denied

```bash
# Test sudo access
ssh username@192.168.1.66 "sudo -v"

# If it fails:
# 1. Ask your system admin to add you to sudo group
# 2. Or provide your password when prompted during deployment
```

### Problem: Passwordless Sudo Not Working

```bash
# On the server, check sudo configuration:
ssh username@192.168.1.66
sudo cat /etc/sudoers.d/username  # or check /etc/sudoers

# Make sure your user is configured for NOPASSWD
```

### Problem: Directory Permission Denied

If you see permission errors during deployment, ensure:

```bash
# Your user needs write access to deployment directories
ssh username@192.168.1.66 "sudo chown -R username:username /var/www/mxa-ocr-app" 
ssh username@192.168.1.90 "sudo chown -R username:username /opt/apps/mxa-ocr"
```

## Differences from Root Deployment

| Aspect | Root Deployment | Non-Root Deployment |
|--------|----------------|---------------------|
| SSH User | `root` | Your username |
| Commands | Direct execution | Uses `sudo` |
| Setup | Single username | Can use different usernames per server |
| Security | Less secure | More secure (principle of least privilege) |

## Security Best Practices

1. ✅ **Use SSH keys** instead of passwords
2. ✅ **Different SSH key per environment** (dev, staging, prod)
3. ✅ **Limit sudo access** to only required commands
4. ✅ **Audit logs** for sudo command usage
5. ✅ **Regular key rotation** (change SSH keys periodically)
6. ✅ **Use jump hosts** if deploying from outside network

## After Deployment

Once deployment completes, you'll need to:

1. **Configure .env files** with actual credentials
2. **Set up Keycloak** for authentication
3. **Test the application**
4. **Configure SSL certificates**
5. **Set up monitoring**

## Accessing Servers After Deployment

```bash
# SSH to servers using your credentials
ssh john@192.168.1.66  # App Server
ssh jane@192.168.1.90  # Python Server  
ssh admin@192.168.1.59 # SSO Server

# View logs (requires sudo)
ssh john@192.168.1.66 "sudo tail -f /var/log/apache2/mxa-ocr-error.log"
ssh jane@192.168.1.90 "sudo journalctl -u mxa-ocr-api -f"

# Restart services (requires sudo)
ssh jane@192.168.1.90 "sudo systemctl restart mxa-ocr-api"
```

## Support

If you encounter issues:

1. Check SSH connectivity: `ssh username@server "echo test"`
2. Verify sudo access: `ssh username@server "sudo -v"`
3. Review deployment logs in the terminal
4. Check service logs on the servers
5. Consult the main deployment documentation

---

**Created:** 2026-04-11  
**Version:** 1.0.0  
**For:** Non-root SSH deployments with custom usernames
