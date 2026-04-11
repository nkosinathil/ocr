# Sudo Password Deployment Guide

## Problem Fixed

The deployment script now properly handles sudo password prompts when passwordless sudo is not configured.

**Previous Error:**
```
sudo: a terminal is required to read the password
Pseudo-terminal will not be allocated because stdin is not a terminal
```

**Root Cause:** Using `ssh -t` with heredoc (`<< ENDSSH`) redirects stdin from the heredoc content, not from your terminal, preventing sudo from reading passwords interactively.

## Solution Implemented

The script now:
1. **Detects** if passwordless sudo is configured
2. **Prompts once** for passwords at the beginning (if needed)
3. **Passes passwords** securely to sudo using `-S` flag
4. **Works with both** passwordless and password-based sudo

## How to Use

### Option 1: Configure Passwordless Sudo (Recommended)

On each server, run:
```bash
sudo visudo
```

Add these lines (replace with your actual usernames):
```
apps ALL=(ALL) NOPASSWD:ALL
pyminio ALL=(ALL) NOPASSWD:ALL
ssoadmin ALL=(ALL) NOPASSWD:ALL
```

Save and exit (Ctrl+X, Y, Enter).

### Option 2: Use Password-Based Sudo (Now Fixed!)

Just run the deployment script normally:
```bash
cd deploy/scripts
bash deploy-quick.sh
```

When prompted:
1. Enter your usernames for each server
2. Confirm deployment (type `yes`)
3. **Enter sudo password for App Server** when prompted
4. **Enter sudo password for Python Server** when prompted
5. Script runs without further password prompts

## Example Session

```bash
$ cd deploy/scripts
$ bash deploy-quick.sh

==================================================================
MXA OCR - Quick Deployment Setup
==================================================================

Enter your SSH username for each server:

Username for App Server []: apps
Username for Python Server []: pyminio
Username for SSO Server []: ssoadmin

...

>>> Checking sudo access on apps@192.168.1.66...
✗ Passwordless sudo is not configured
ℹ You may be prompted for sudo password during deployment

>>> Password required for sudo on App Server
Enter sudo password for apps@192.168.1.66: [hidden]

>>> Password required for sudo on Python Server
Enter sudo password for pyminio@192.168.1.90: [hidden]

>>> Extracting and deploying on App Server...
✓ Code deployed to App Server
...
```

## Security Notes

1. **Passwords are not stored** - only kept in memory during script execution
2. **Passwords are hidden** when typing (using `read -s`)
3. **Passwords are cleared** after script completes
4. **SSH encryption** protects passwords in transit

## Technical Details

### What Changed

**Before (Broken):**
```bash
ssh -t ${USER}@${HOST} << ENDSSH
    sudo mkdir -p /path
ENDSSH
```
- `-t` requests PTY allocation
- Heredoc redirects stdin from script content
- SSH refuses PTY because stdin is not a terminal
- Sudo can't read password

**After (Fixed):**
```bash
if [ -n "$SUDO_PASS" ]; then
    ssh ${USER}@${HOST} bash -s << ENDSSH
        echo '$SUDO_PASS' | sudo -S mkdir -p /path
    ENDSSH
else
    ssh ${USER}@${HOST} bash -s << ENDSSH
        sudo mkdir -p /path
    ENDSSH
fi
```
- Removed `-t` flag (not needed for non-interactive commands)
- Used `sudo -S` to read password from stdin
- Echoed password into sudo via pipe
- Dual paths for passwordless and password-based sudo

### Why This Works

1. **No PTY needed** - Commands are non-interactive
2. **Password from stdin** - `sudo -S` reads from pipe
3. **Single prompt** - Password entered once, reused throughout
4. **Backward compatible** - Passwordless sudo still works

## Troubleshooting

### Password Prompt Not Appearing

**Cause:** Passwordless sudo is already configured  
**Solution:** This is fine! Script detects it and skips password prompt.

### "sudo: a password is required" During Execution

**Cause:** Password was entered incorrectly  
**Solution:** Re-run script and enter correct password.

### Password Prompt Appears Multiple Times

**Cause:** Password timeout on server (sudo cached password expired)  
**Solution:** Script prompts once; if it prompts again, your server has a very short sudo timeout.

### Still Getting "stdin is not a terminal"

**Cause:** You may be running an older version of the script  
**Solution:** Pull latest changes:
```bash
git fetch origin copilot/setup-self-contained-product
git reset --hard origin/copilot/setup-self-contained-product
```

## Best Practices

1. **Use passwordless sudo** for automated deployments
2. **Use strong passwords** if using password-based sudo
3. **Limit sudo access** to only required commands (advanced)
4. **Audit deployment logs** to track who deployed what
5. **Use SSH keys** instead of SSH passwords

## Related Documentation

- [NON-ROOT-DEPLOYMENT.md](NON-ROOT-DEPLOYMENT.md) - Complete non-root deployment guide
- [NON-ROOT-QUICK-REF.txt](NON-ROOT-QUICK-REF.txt) - Quick reference
- [deploy/scripts/README.md](scripts/README.md) - All deployment scripts

---

**Last Updated:** 2026-04-11  
**Fix Version:** commit 8870118
