# Check Quotas Script

Simple script to check API quota status across multiple providers.

## Installation

1. Copy `check-quotas.sh` to your local bin directory:

```bash
cp check-quotas.sh ~/.local/bin/check-quotas
chmod +x ~/.local/bin/check-quotas
```

2. Verify `~/.local/bin` is in your PATH:

```bash
echo $PATH | grep -q "$HOME/.local/bin" || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

## Configuration

The script looks for API keys in `~/.openclaw/credentials/` by default.

**Override with environment variables:**

```bash
export OPENCLAW_CREDENTIALS_DIR="/path/to/your/credentials"
export CLAUDE_KEYCHAIN_ITEM="Your-Keychain-Item"
```

**Expected credential files:**

Each file should contain **only the raw API key** (no variable names, no quotes, no newlines):

```bash
# Correct format - just the raw token:
echo "sk-ant-api03-xxxxxxxxxxxx" > ~/.openclaw/credentials/anthropic

# Wrong format - do NOT use:
echo "ANTHROPIC_API_KEY=sk-ant-api03-xxxxxxxxxxxx" > ~/.openclaw/credentials/anthropic
```

**Files the script looks for:**
- `$CREDENTIALS_DIR/synthetic` - Synthetic API key (raw token only)
- `$CREDENTIALS_DIR/openrouter` - OpenRouter API key (raw token only)
- `$CREDENTIALS_DIR/anthropic` - Anthropic API key (raw token only)

**macOS Keychain (Claude Code):**
- The script checks macOS Keychain for Claude Code OAuth credentials
- Only works on macOS with Claude Code installed

## Usage

Run from anywhere:

```bash
check-quotas
```

**Output format (JSON):**

```json
{
  "claude_code": {
    "usage": {...},
    "limit": {...}
  },
  "synthetic": {
    "credits_remaining": 1000
  },
  "openrouter": {
    "usage": 45.23,
    "limit": 100.00
  },
  "anthropic_api": "valid",
  "checked_at": "2026-02-09T20:28:00Z"
}
```

## Parsing Output

**Check if a provider is over 90% quota:**

```bash
check-quotas | jq '.openrouter | (.usage / .limit) > 0.9'
```

**Get remaining Synthetic credits:**

```bash
check-quotas | jq -r '.synthetic.credits_remaining'
```

**Pretty print for humans:**

```bash
check-quotas | jq .
```

## Adding New Providers

To add a new provider, create a function following this pattern:

```bash
check_yourprovider() {
    local api_key=$(cat "$CREDENTIALS_DIR/yourprovider" 2>/dev/null || echo "")
    
    if [ -z "$api_key" ]; then
        echo "null"
        return
    fi
    
    curl -s https://api.yourprovider.com/quota \
        -H "Authorization: Bearer $api_key" 2>/dev/null || echo "null"
}
```

Then add it to the final jq output.

## Integration with OpenClaw

Use in agent prompts or skills:

```bash
# Before spawning expensive agent, check quotas
QUOTAS=$(check-quotas)
OPENROUTER_USAGE=$(echo $QUOTAS | jq -r '.openrouter.usage // 0')

if [ "$OPENROUTER_USAGE" -gt 90 ]; then
    echo "OpenRouter quota high, using fallback"
fi
```

## Requirements

- `bash`
- `curl`
- `jq`
- `security` (macOS only, for Keychain access)

## Limitations

- Claude Code check only works on macOS
- Anthropic API has no public quota endpoint, so we just verify the key works
- Rate limits may apply to quota check APIs themselves

## Security

The script reads API keys from files. Each file should contain **only the raw token** with no variable names or formatting.

**Creating credential files:**

```bash
# Create credentials directory
mkdir -p ~/.openclaw/credentials

# Add your API keys (raw tokens only, no quotes)
echo "your-api-key-here" > ~/.openclaw/credentials/openrouter
echo "your-api-key-here" > ~/.openclaw/credentials/synthetic
echo "your-api-key-here" > ~/.openclaw/credentials/anthropic

# Set proper permissions
chmod 700 ~/.openclaw/credentials
chmod 600 ~/.openclaw/credentials/*
```

**File format:**
- ✅ Correct: `sk-ant-api03-xxxxx` (raw token only)
- ❌ Wrong: `ANTHROPIC_API_KEY=sk-ant-api03-xxxxx` (no ENV format)
- ❌ Wrong: `"sk-ant-api03-xxxxx"` (no quotes)

Never commit API keys to git or share the output publicly.
