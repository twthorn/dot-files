#!/bin/bash

# Tests _update_claude_settings in setup.sh: it writes the permission rules (with
# the MCP allows and Slack send denies), pins the classic "tui" renderer so tmux
# copy-mode can scroll Claude, and keeps every other setting. An empty or
# unreadable settings file is set aside as <file>.invalid and rebuilt rather than
# making jq fail -- a failed jq must never overwrite settings with empty output.
# Writes to a throwaway directory only.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
SETTINGS="$TEST_DIR/settings.json"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/../setup.sh"

FAIL=0
check() { # desc expected actual
    if [[ "$2" == "$3" ]]; then
        echo "  ok: $1"
    else
        echo "  FAIL: $1 (expected '$2', got '$3')"
        FAIL=1
    fi
}

echo '{"model":"opus","tui":"fullscreen","permissions":{"allow":["Old(*)"]}}' > "$SETTINGS"
_update_claude_settings "$SETTINGS" '["mcp__ats__*"]'
check "MCP allows are added" "true" "$(jq '.permissions.allow | index("mcp__ats__*") != null' "$SETTINGS")"
check "old allow rules are replaced" "false" "$(jq '.permissions.allow | index("Old(*)") != null' "$SETTINGS")"
check "Slack send is denied" "true" "$(jq '.permissions.deny | index("mcp__*__slack_send_message") != null' "$SETTINGS")"
check "builtin denies are kept" "true" "$(jq '.permissions.deny | index("Bash(rm -rf *)") != null' "$SETTINGS")"
check "classic renderer is pinned" "default" "$(jq -r '.tui' "$SETTINGS")"
check "other settings are kept" "opus" "$(jq -r '.model' "$SETTINGS")"

printf '\n' > "$SETTINGS"
_update_claude_settings "$SETTINGS" '[]'
check "an empty file is rebuilt into valid settings" "default" "$(jq -r '.tui' "$SETTINGS")"

printf '{"model": "opus",' > "$SETTINGS"
_update_claude_settings "$SETTINGS" '[]'
check "an unreadable file is rebuilt" "true" "$(jq '.permissions.deny | length > 0' "$SETTINGS")"
check "an unreadable file is kept aside" '{"model": "opus",' "$(cat "$SETTINGS.invalid")"

echo '{"model":"opus"}' > "$SETTINGS"
_update_claude_settings "$SETTINGS" 'not json' 2>/dev/null
check "a failed update leaves the file untouched" '{"model":"opus"}' "$(cat "$SETTINGS")"

if [[ "$FAIL" -eq 0 ]]; then
    echo "ALL PASS"
else
    echo "FAILURES"
    exit 1
fi
