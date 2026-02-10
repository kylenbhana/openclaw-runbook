#!/bin/bash
# Check API quotas for various providers
# Returns JSON with quota status
#
# Usage: ./check-quotas.sh
#
# Configure paths below or set environment variables:
#   OPENCLAW_SECRETS_DIR - Path to your secrets directory
#   CLAUDE_KEYCHAIN_ITEM - macOS Keychain item name for Claude credentials

set -euo pipefail

# Configuration - adjust these paths for your setup
CREDENTIALS_DIR="${OPENCLAW_CREDENTIALS_DIR:-$HOME/.openclaw/credentials}"
CLAUDE_KEYCHAIN="${CLAUDE_KEYCHAIN_ITEM:-Claude Code-credentials}"

# Check Claude Code quota (macOS Keychain)
check_claude_code() {
    # Only works on macOS with Claude Code credentials in Keychain
    if ! command -v security &> /dev/null; then
        echo "null"
        return
    fi
    
    local token=$(security find-generic-password -s "$CLAUDE_KEYCHAIN" -w 2>/dev/null | jq -r '.claudeAiOauth.accessToken' 2>/dev/null || echo "")
    
    if [ -z "$token" ] || [ "$token" = "null" ]; then
        echo "null"
        return
    fi
    
    curl -s https://api.anthropic.com/api/oauth/usage \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -H "User-Agent: claude-code/2.0.32" \
        -H "Authorization: Bearer $token" \
        -H "anthropic-beta: oauth-2025-04-20" 2>/dev/null || echo "null"
}

# Check Synthetic quota
check_synthetic() {
    local api_key=$(cat "$CREDENTIALS_DIR/synthetic" 2>/dev/null || echo "")
    
    if [ -z "$api_key" ]; then
        echo "null"
        return
    fi
    
    curl -s https://api.synthetic.new/v2/quotas \
        -H "Authorization: Bearer $api_key" 2>/dev/null || echo "null"
}

# Check OpenRouter quota
check_openrouter() {
    local api_key=$(cat "$CREDENTIALS_DIR/openrouter" 2>/dev/null || echo "")
    
    if [ -z "$api_key" ]; then
        echo "null"
        return
    fi
    
    curl -s https://openrouter.ai/api/v1/key \
        -H "Authorization: Bearer $api_key" 2>/dev/null || echo "null"
}

# Check Anthropic API quota (direct API key)
check_anthropic() {
    local api_key=$(cat "$CREDENTIALS_DIR/anthropic" 2>/dev/null || echo "")
    
    if [ -z "$api_key" ]; then
        echo "null"
        return
    fi
    
    # Note: Anthropic API doesn't have a public quota endpoint
    # This just verifies the key works
    curl -s https://api.anthropic.com/v1/messages \
        -H "x-api-key: $api_key" \
        -H "anthropic-version: 2023-06-01" \
        -H "content-type: application/json" \
        -d '{"model":"claude-3-haiku-20240307","max_tokens":1,"messages":[{"role":"user","content":"test"}]}' 2>/dev/null | \
        jq -r 'if .error then "error" else "valid" end' || echo "null"
}

# Build combined JSON output
claude_quota=$(check_claude_code)
synthetic_quota=$(check_synthetic)
openrouter_quota=$(check_openrouter)
anthropic_quota=$(check_anthropic)

jq -n \
    --argjson claude "$claude_quota" \
    --argjson synthetic "$synthetic_quota" \
    --argjson openrouter "$openrouter_quota" \
    --arg anthropic "$anthropic_quota" \
    '{
        claude_code: $claude,
        synthetic: $synthetic,
        openrouter: $openrouter,
        anthropic_api: $anthropic,
        checked_at: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
    }'
