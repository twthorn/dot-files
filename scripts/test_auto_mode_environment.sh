#!/bin/bash

# Tests _apply_auto_mode_environment in setup.sh: the trusted source-control orgs
# Claude may push and open PRs to are derived from the private config -- the
# enterprise org from ENTERPRISE_NAME (<name>-github.com/<name>) and each of
# TRUSTED_GITHUB_ORGS on github.com -- and written to autoMode.environment after
# "$defaults", so the built-in entries stay. Rerunning replaces rather than
# duplicates; other settings are kept; with nothing configured the block is
# removed. Writes to a throwaway settings file only.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
SETTINGS="$TEST_DIR/settings.json"
echo '{"tui":"default","permissions":{"allow":["Read(*)"]}}' > "$SETTINGS"

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
entry() { jq -r ".autoMode.environment[$1]" "$SETTINGS"; }

ENTERPRISE_NAME="acme"
TRUSTED_GITHUB_ORGS=("acmehq" "acme-labs")
_apply_auto_mode_environment "$SETTINGS"
check "built-in entries kept first" '$defaults' "$(entry 0)"
check "enterprise org trusted" \
    "Source control: acme-github.com/acme and all repos under it (~/git/acme/)" "$(entry 1)"
check "public github.com org trusted, own work only" \
    "Source control: github.com/acmehq and all repos under it (~/git/acmehq/). These repos are public: pushing branches and opening pull requests there is routine, but only each repo's own work belongs there; internal or confidential material must never be pushed to them." \
    "$(entry 2)"
check "every listed org trusted" "github.com/acme-labs" "$(entry 3 | grep -o 'github.com/acme-labs')"
check "other settings kept" '"default" ["Read(*)"]' "$(jq -c '.tui, .permissions.allow' "$SETTINGS" | tr '\n' ' ' | sed 's/ $//')"

_apply_auto_mode_environment "$SETTINGS"
check "rerun does not duplicate" "4" "$(jq '.autoMode.environment | length' "$SETTINGS")"

unset ENTERPRISE_NAME
_apply_auto_mode_environment "$SETTINGS"
check "github.com orgs alone" "3" "$(jq '.autoMode.environment | length' "$SETTINGS")"

TRUSTED_GITHUB_ORGS=()
_apply_auto_mode_environment "$SETTINGS"
check "nothing configured removes the block" "null" "$(jq -c '.autoMode' "$SETTINGS")"

if [[ "$FAIL" -eq 0 ]]; then
    echo "ALL PASS"
else
    echo "FAILURES"
    exit 1
fi
