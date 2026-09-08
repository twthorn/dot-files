#!/bin/bash

# Tests for _fix_git_identity in fix_git_identity.sh. Runs against a throwaway
# HOME and throwaway repos so it exercises real `git config` include/includeIf
# resolution -- no mocking. Confirms:
#   - personal email is the default identity for any repo
#   - repos under WORK_GIT_DIRS resolve to the work email (includeIf generated)
#   - a stray top-level user.email is removed so it can't shadow the includeIf
#   - global user.name is set from GIT_NAME
#   - stale local user.name/email overrides in repos are stripped
#   - --dry-run reports every mismatch but changes nothing

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP="$SCRIPT_DIR/fix_git_identity.sh"

# Isolate git from the real machine.
export GIT_CONFIG_NOSYSTEM=1
unset GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM GIT_AUTHOR_EMAIL GIT_COMMITTER_EMAIL 2>/dev/null

FAIL=0
check() { # desc expected actual
    if [[ "$2" == "$3" ]]; then
        echo "  ok: $1"
    else
        echo "  FAIL: $1 (expected '$2', got '$3')"
        FAIL=1
    fi
}
check_contains() { # desc needle haystack
    if echo "$3" | grep -q -- "$2"; then
        echo "  ok: $1"
    else
        echo "  FAIL: $1 (output missing '$2')"
        FAIL=1
    fi
}

# Real path (resolve macOS /var -> /private/var symlink) so includeIf gitdir matches.
TESTHOME="$(cd "$(mktemp -d)" && pwd -P)"
export HOME="$TESTHOME"
export GIT_REPO_ROOT="$TESTHOME/git"
export GIT_NAME="Test User"
export GIT_EMAIL="personal@example.com"
export WORK_EMAIL="work@slack-corp.com"
WORK_GIT_DIRS=("~/git/slack/")

# Seed a broken global config: NO includes, plus a shadowing top-level user.email
# and a stale name -- exactly the drift we are repairing.
cat > "$HOME/.gitconfig" <<EOF
[user]
	name = Old Name
	email = shadow@example.com
EOF

mkdir -p "$GIT_REPO_ROOT/slack/webapp" "$GIT_REPO_ROOT/personal/proj"
git -C "$GIT_REPO_ROOT/slack/webapp"   init -q
git -C "$GIT_REPO_ROOT/personal/proj"  init -q
# Stale local overrides that must be stripped.
git -C "$GIT_REPO_ROOT/slack/webapp"  config --local user.email "stale-work@wrong.com"
git -C "$GIT_REPO_ROOT/slack/webapp"  config --local user.name  "Stale Name"
git -C "$GIT_REPO_ROOT/personal/proj" config --local user.email "stale-personal@wrong.com"

# shellcheck disable=SC1090
source "$SETUP"

# Dry-run must report the mismatches WITHOUT changing anything.
DRY_OUT="$(_fix_git_identity --dry-run)"
check_contains "dry-run reports changes needed" "change(s) needed"    "$DRY_OUT"
check "dry-run leaves global shadow"     "shadow@example.com"   "$(git config --global --get user.email 2>/dev/null)"
check "dry-run leaves slack local"       "stale-work@wrong.com" "$(git -C "$GIT_REPO_ROOT/slack/webapp"  config --local --get user.email 2>/dev/null)"
check "dry-run adds no include"          "0"                    "$(git config --global --get-all include.path 2>/dev/null | grep -cxF '~/.gitconfig-personal')"

# Now apply for real.
_fix_git_identity >/dev/null

check "slack repo uses work email"       "work@slack-corp.com"  "$(git -C "$GIT_REPO_ROOT/slack/webapp"  config user.email)"
check "personal repo uses personal"      "personal@example.com" "$(git -C "$GIT_REPO_ROOT/personal/proj" config user.email)"
check "both repos share global name"     "Test User"            "$(git -C "$GIT_REPO_ROOT/slack/webapp"  config user.name)"
check "no global shadow email"           ""                     "$(git config --global --get user.email 2>/dev/null)"
check "global name updated"              "Test User"            "$(git config --global user.name)"
check "slack local email stripped"       ""                     "$(git -C "$GIT_REPO_ROOT/slack/webapp"  config --local --get user.email 2>/dev/null)"
check "slack local name stripped"        ""                     "$(git -C "$GIT_REPO_ROOT/slack/webapp"  config --local --get user.name 2>/dev/null)"

# Idempotency: a second run must not duplicate includes or change results.
_fix_git_identity >/dev/null
check "idempotent: one personal include" "1" "$(git config --global --get-all include.path | grep -cxF '~/.gitconfig-personal')"
check "idempotent: slack still work"     "work@slack-corp.com"  "$(git -C "$GIT_REPO_ROOT/slack/webapp" config user.email)"

# After a successful fix, dry-run must report a clean state.
DRY_CLEAN="$(_fix_git_identity --dry-run)"
check_contains "dry-run clean after fix"  "no changes needed"    "$DRY_CLEAN"

rm -rf "$TESTHOME"
if [[ "$FAIL" -eq 0 ]]; then
    echo "ALL PASS"
else
    echo "FAILURES"
    exit 1
fi
