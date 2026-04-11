# SSH Setup Guide for Windows/Git Bash Users

## Problem

When running the deployment script on Windows using Git Bash, you may encounter SSH connection failures even after running `ssh-copy-id`:

```
✗ Cannot connect to apps@192.168.1.66
ℹ Make sure SSH keys are set up: ssh-copy-id apps@192.168.1.66
```

This happens because:
1. **SSH Agent**: The SSH agent may not be running or may not have your key loaded
2. **Host Key Verification**: First-time connections require accepting the host key
3. **File Permissions**: Windows file permissions may not translate correctly to Unix permissions

## Quick Solution

We've created a helper script that handles all the setup automatically:

```bash
cd deploy/scripts
bash setup-ssh-keys.sh
```

This script will:
- ✓ Generate an SSH key if you don't have one
- ✓ Start the SSH agent and load your key
- ✓ Copy your key to all deployment servers
- ✓ Test all connections
- ✓ Save agent info to `~/.ssh/mxa-ocr-agent-info` for reuse
- ✓ Give you clear troubleshooting steps if something fails

**Important:** After running the setup script, you have two options:

**Option 1: Source the agent info (Recommended)**
```bash
source ~/.ssh/mxa-ocr-agent-info
bash deploy-quick.sh
```

**Option 2: Run both commands together**
```bash
source ~/.ssh/mxa-ocr-agent-info && bash deploy-quick.sh
```

The deployment script will automatically try to load the agent info, but sourcing it ensures it's available in your current shell.

## Manual Solution

If you prefer to set up SSH manually, follow these steps:

### Step 1: Generate SSH Key (if needed)

```bash
# Check if you have a key
ls ~/.ssh/id_rsa*

# If not, generate one
ssh-keygen -t rsa -b 4096
# Press Enter to accept defaults
```

### Step 2: Start SSH Agent and Add Key

This is **critical** for Git Bash on Windows:

```bash
# Start the SSH agent
eval "$(ssh-agent -s)"

# Add your key to the agent
ssh-add ~/.ssh/id_rsa

# Verify it's loaded
ssh-add -l
```

### Step 3: Copy Keys to Servers

```bash
# Copy to each server (you'll be prompted for passwords)
ssh-copy-id apps@192.168.1.66
ssh-copy-id pyminio@192.168.1.90
ssh-copy-id ssoadmin@192.168.1.59
```

### Step 4: Test Connections

```bash
# Test each connection (should work without password)
ssh -o BatchMode=yes apps@192.168.1.66 exit
ssh -o BatchMode=yes pyminio@192.168.1.90 exit
ssh -o BatchMode=yes ssoadmin@192.168.1.59 exit
```

If all three commands succeed silently, you're ready to deploy!

## Troubleshooting

### Issue: Setup script works, but deployment script fails with "SSH agent not running"

This is the **most common issue**! The setup script starts an SSH agent in one shell session, but when you run the deployment script in a new bash invocation, it doesn't have access to that agent.

**Solution 1: Source the agent info (Recommended)**
```bash
source ~/.ssh/mxa-ocr-agent-info
bash deploy-quick.sh
```

**Solution 2: Run in one command**
```bash
source ~/.ssh/mxa-ocr-agent-info && bash deploy-quick.sh
```

**Solution 3: Make agent persistent (Best for repeated deployments)**
Add to your `~/.bashrc`:
```bash
# Load MXA OCR SSH agent if available
if [ -f ~/.ssh/mxa-ocr-agent-info ]; then
    source ~/.ssh/mxa-ocr-agent-info
fi
```

Then reload: `source ~/.bashrc`

### Issue: "SSH agent not running"

**Solution:**
```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa
```

You need to do this every time you open a new Git Bash window, or add these lines to your `~/.bashrc` file.

### Issue: "Permission denied (publickey)"

**Possible causes:**
1. SSH agent doesn't have your key loaded
2. Wrong username
3. Key not copied to server

**Solution:**
```bash
# Check if key is loaded
ssh-add -l

# If not, add it
ssh-add ~/.ssh/id_rsa

# Try copying the key again
ssh-copy-id apps@192.168.1.66
```

### Issue: "Host key verification failed"

**Solution:**
Accept the host key on first connection:
```bash
ssh apps@192.168.1.66
# Type "yes" when prompted about host authenticity
exit
```

Or bypass host key checking (less secure, but useful for known private networks):
```bash
ssh -o StrictHostKeyChecking=no apps@192.168.1.66
```

### Issue: Still not working after ssh-copy-id

**Check these:**

1. **Verify the key was copied:**
   ```bash
   ssh apps@192.168.1.66 "cat ~/.ssh/authorized_keys"
   ```
   Your public key should be listed there.

2. **Check SSH agent:**
   ```bash
   echo $SSH_AUTH_SOCK
   ```
   Should show a path. If empty, agent isn't running.

3. **Check key permissions:**
   ```bash
   ls -la ~/.ssh/id_rsa
   ```
   Should be `-rw-------` (600). If not:
   ```bash
   chmod 600 ~/.ssh/id_rsa
   ```

4. **Try verbose SSH to see what's failing:**
   ```bash
   ssh -vvv apps@192.168.1.66
   ```

## Important Notes for Windows Users

1. **Every new Git Bash window needs SSH agent started** unless you add it to `~/.bashrc`:
   ```bash
   echo 'eval "$(ssh-agent -s)" > /dev/null 2>&1' >> ~/.bashrc
   echo 'ssh-add ~/.ssh/id_rsa > /dev/null 2>&1' >> ~/.bashrc
   ```

2. **Windows paths**: Git Bash sees `C:\Users\nkosi` as `/c/Users/nkosi`

3. **Administrator privileges**: Some SSH operations may require running Git Bash as Administrator

4. **PuTTY users**: If you normally use PuTTY, you need to either:
   - Use `pageant` to load your PuTTY key (`.ppk` file), OR
   - Convert your PuTTY key to OpenSSH format using PuTTYgen, OR
   - Generate a new OpenSSH key with `ssh-keygen`

## Recommended: Persistent SSH Agent Setup

Add this to `~/.bashrc` to avoid manually starting the agent every time:

```bash
# Start SSH agent if not running
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)" > /dev/null 2>&1
    ssh-add ~/.ssh/id_rsa > /dev/null 2>&1
fi
```

Then reload:
```bash
source ~/.bashrc
```

## Ready to Deploy

Once SSH is working, run:

```bash
cd deploy/scripts
bash deploy-quick.sh
```

The deployment script will now be able to connect to all servers without password prompts!
