# VPS Setup Guide

This guide covers setting up OpenClaw on a VPS with security hardening.

## Hardware Requirements

You don't need a large machine. A Hetzner CX23 or equivalent is plenty:
- 2 vCPUs
- 4 GB RAM
- 40 GB disk

## Network Security with Tailscale

**CRITICAL: Follow this order exactly to avoid lockout.**

### Step 1: Install Tailscale on Local Machine

```bash
# On your local machine (Mac/Linux/Windows)
# Visit: https://tailscale.com/download
# Install and authenticate
```

### Step 2: Install Tailscale on VPS

```bash
# SSH into VPS normally first
ssh user@your-vps-ip

# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --ssh=true
```

The `--ssh=true` flag enables SSH over Tailscale.

### Step 3: Get VPS Tailscale IP

```bash
# On VPS, get your Tailscale IP
tailscale ip -4
# Example output: 100.64.1.2
```

### Step 4: TEST SSH via Tailscale

**CRITICAL: Do NOT skip this step.**

From your local machine, test SSH over Tailscale:

```bash
# Use the Tailscale IP, NOT your public IP
ssh user@100.64.1.2
```

**If this works, you're ready to block public SSH.**
**If this fails, DO NOT proceed. Debug Tailscale first.**

### Step 5: Block Public Access (Only After Verification)

Now that Tailscale SSH is verified, block port 22 at the firewall:

```bash
# Hetzner firewall (via web UI)
# 1. Create new firewall rule
# 2. Block: All inbound traffic on port 22
# 3. Leave Tailscale traffic unrestricted (100.64.0.0/10)
```

### Step 6: Verify Lockout Prevention

Test one more time:

```bash
# This should work (Tailscale)
ssh user@100.64.1.2

# This should fail/timeout (public IP blocked)
ssh user@your-public-vps-ip
```

**If Tailscale SSH fails at this point, you can still access via your provider's web console to fix it.**

### Safety Net

Most VPS providers (Hetzner, DigitalOcean, Linode) offer web-based console access as a last resort if you lock yourself out. Find this BEFORE making firewall changes.

## OpenClaw Installation

After installing OpenClaw, run these commands before doing anything else:

```bash
# Validate config and auto-fix common issues
openclaw doctor --fix

# Run a deep security scan
openclaw security audit --deep
```

The security audit should return zero critical issues. A couple of warnings is normal:
- `gateway.trusted_proxies_missing` (ok if localhost-only)
- `fs.credentials_dir.perms_readable` (fix with chmod)

## File Permissions

Lock down the config directory:

```bash
chmod 700 ~/.openclaw
chmod 600 ~/.openclaw/openclaw.json
chmod 700 ~/.openclaw/credentials
```

This prevents other users on the system from reading your config or API keys.

## Gateway Binding

Verify the gateway is binding to localhost and not exposed to the public internet:

```bash
netstat -an | grep 18789 | grep LISTEN
# You want to see: 127.0.0.1:18789
# You do NOT want: 0.0.0.0:18789
```

If you see `0.0.0.0`, your gateway is listening on all interfaces and anyone who can reach that port can talk to your agent.

**Fix it in config:**

```json
"gateway": {
  "bind": "loopback"
}
```

Then restart:

```bash
openclaw gateway restart
```

## Hardening Configuration

Once the basics are locked down, configure these settings:

### Logging with Redaction

```json
"logging": {
  "redactSensitive": "tools"
}
```

Options:
- `"off"` - No redaction (dangerous)
- `"tools"` - Redact tool output (recommended)
- `"all"` - Aggressive redaction (harder debugging)

### Tool Policies

Restrict which tools agents can use:

```json
"tools": {
  "profile": "minimal",
  "deny": ["exec"],
  "allow": ["web_search", "web_fetch", "read"]
}
```

**Tool profiles:**
- `minimal` - Only `session_status` (most restrictive)
- `coding` - File system, runtime, sessions, memory
- `messaging` - Messaging tools only
- `full` - No restrictions (default)

This prevents agents from executing arbitrary commands without explicit permission.

### Sandbox Mode (Optional)

If you want containerized execution (requires Docker):

```json
"agents": {
  "defaults": {
    "sandbox": {
      "enabled": true,
      "image": "openclaw-sandbox"
    }
  }
}
```

Useful if running on a shared VPS and want agent work isolated.

## Git-Track Your Config

Git-track the OpenClaw config directory for rollback capability:

```bash
cd ~/.openclaw && git init
printf 'agents/*/sessions/\nagents/*/agent/*.jsonl\n*.log\n' > .gitignore
git add .gitignore openclaw.json
git commit -m "config: baseline"
```

After that, commit before and after any significant change:

```bash
# Before making changes
git commit -am "config: before model update"

# Make your changes
vim openclaw.json

# Test and commit
openclaw doctor --fix
git commit -am "config: switched to Gemini 3 Flash"
```

When something breaks at midnight, `git diff` and `git checkout` are faster than trying to remember what you changed.

## Validation Workflow

After any config change:

1. **Validate:**
   ```bash
   openclaw doctor --fix
   ```

2. **Security audit:**
   ```bash
   openclaw security audit --deep
   ```

3. **Test:**
   ```bash
   openclaw status
   # Send a test message
   ```

4. **Commit:**
   ```bash
   git commit -am "config: description of change"
   ```

This workflow catches mistakes quickly and gives you rollback capability.

## System Monitoring

Set up basic monitoring:

```bash
# Check OpenClaw status
openclaw status

# Check for errors in logs
tail -100 ~/.openclaw/gateway.log | grep -i error

# Check system resources
htop
```

Consider adding a cron job or heartbeat check for failed jobs and error logs (see `heartbeat-example.md`).

## Backup Strategy

What to backup:
- `~/.openclaw/openclaw.json` (config)
- `~/.openclaw/credentials/` (API keys)
- `~/.openclaw/workspace/` (your work)

What NOT to backup:
- Session logs (recreated)
- Agent state (regenerated)
- Log files (ephemeral)

### Backup Script

Create `~/bin/backup-openclaw.sh`:

```bash
#!/bin/bash
# OpenClaw backup script
BACKUP_DIR=~/backups
DATE=$(date +%Y-%m-%d)

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Create backup
tar czf $BACKUP_DIR/openclaw-$DATE.tar.gz \
  ~/.openclaw/openclaw.json \
  ~/.openclaw/credentials \
  ~/.openclaw/workspace

# Keep only last 7 days of backups
find $BACKUP_DIR -name "openclaw-*.tar.gz" -mtime +7 -delete

# Log completion
echo "$(date): Backup completed - openclaw-$DATE.tar.gz" >> $BACKUP_DIR/backup.log
```

Make it executable:

```bash
chmod +x ~/bin/backup-openclaw.sh
```

### Schedule with Cron

Edit your crontab:

```bash
crontab -e
```

Add one of these schedules:

```bash
# Daily at 3 AM
0 3 * * * ~/bin/backup-openclaw.sh

# Every 6 hours
0 */6 * * * ~/bin/backup-openclaw.sh

# Weekly on Sunday at 2 AM
0 2 * * 0 ~/bin/backup-openclaw.sh
```

**Verify cron job is scheduled:**

```bash
crontab -l
```

**Check backup logs:**

```bash
cat ~/backups/backup.log
```

## Service Management

The OpenClaw wizard automatically sets up a systemd user service on Linux (or launchd on macOS) during installation. No manual configuration needed.

**Check service status:**
```bash
openclaw status
# or
systemctl --user status openclaw
```

**Manage the service:**
```bash
openclaw gateway start
openclaw gateway stop
openclaw gateway restart
```

The wizard handles service installation automatically. Manual systemd setup is only needed for custom configurations or non-wizard installations.

## Tailscale Troubleshooting

**Tailscale SSH not working:**

```bash
# On VPS, check Tailscale status
sudo tailscale status

# Check if SSH is enabled
sudo tailscale status | grep ssh

# If disabled, re-enable
sudo tailscale up --ssh=true
```

**Can't find Tailscale IP:**

```bash
# On VPS
tailscale ip -4    # IPv4
tailscale ip -6    # IPv6
hostname           # Machine name on Tailscale network
```

**Locked out after firewall change:**

1. Use provider's web console (Hetzner Console, DigitalOcean Droplet Console)
2. Log in through web interface
3. Fix firewall rules or re-enable Tailscale
4. Test Tailscale SSH before closing console

## OpenClaw Troubleshooting

**Gateway won't start:**
```bash
openclaw doctor --fix
openclaw gateway stop
openclaw gateway start
```

**Config errors:**
```bash
openclaw doctor --fix
# Read the output, fix issues
```

**Permission denied:**
```bash
ls -la ~/.openclaw
# Check ownership and permissions
chmod 700 ~/.openclaw
chmod 600 ~/.openclaw/openclaw.json
```

**Port already in use:**
```bash
lsof -i :18789
# Kill the process or change the port in config
```

## Security Checklist

Before running OpenClaw in production:

- [ ] File permissions locked down (700/600)
- [ ] Gateway binds to localhost only
- [ ] `openclaw security audit --deep` returns zero critical issues
- [ ] Tailscale configured, SSH blocked at firewall
- [ ] Logging redaction enabled
- [ ] Tool policies configured
- [ ] Config git-tracked
- [ ] Backup strategy in place

## Cost Optimization

Running on a VPS doesn't mean expensive:

- Hetzner CX23: ~$5/month
- Cheap model for heartbeat (GPT-5 nano)
- Cross-provider fallbacks to avoid quota burnout
- Concurrency limits to prevent runaway costs

See `agent-prompts.md` for model configuration strategies.

## Resources

- [Security Patterns](security-patterns.md) - Prompt injection defense and security rules
- [Agent Prompts](agent-prompts.md) - Model configuration and fallback chains
- [Heartbeat Example](heartbeat-example.md) - Rotating checks for monitoring
