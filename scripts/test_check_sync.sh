#!/bin/bash

# Tests the setup.sh --check helpers: a remote whose installed dotfiles, scripts,
# private configs and managed CLAUDE.md block match what local would deploy is
# reported in sync; a changed or missing file is named. The "remote" is a throwaway HOME reached
# through a fake ssh that runs the command locally, so the real hashing and
# comparison code runs without a network.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
REPO="$TEST_DIR/repo"
LOCAL_HOME="$TEST_DIR/local"
REMOTE_HOME="$TEST_DIR/remote"
MARKER="# --- dot-files managed ---"

mkdir -p "$REPO/scripts" "$REPO/.git_template/hooks" "$REPO/.claude" "$LOCAL_HOME"
echo "bashrc v1"  > "$REPO/.bashrc"
echo "tmux v1"    > "$REPO/.tmux.conf"
echo "hook"       > "$REPO/.git_template/hooks/post-commit"
echo "recover v1" > "$REPO/scripts/tmux_recover.sh"
echo "private"    > "$LOCAL_HOME/.bashrc_private"
echo "{}"         > "$LOCAL_HOME/.mcp_private.json"
echo "# Rules"     > "$REPO/.claude/CLAUDE.md"

install_like_setup() {
    rm -rf "$REMOTE_HOME"
    mkdir -p "$REMOTE_HOME/.local/bin" "$REMOTE_HOME/.claude"
    cp -r "$REPO/.bashrc" "$REPO/.tmux.conf" "$REPO/.git_template" "$REMOTE_HOME/"
    cp "$REPO/scripts/tmux_recover.sh" "$REMOTE_HOME/.local/bin/"
    cp "$LOCAL_HOME/.bashrc_private" "$LOCAL_HOME/.mcp_private.json" "$REMOTE_HOME/"
    printf 'remote-only notes\n\n%s\n# Rules\n' "$MARKER" > "$REMOTE_HOME/.claude/CLAUDE.md"
}
fake_ssh() { # host command
    HOME="$REMOTE_HOME" bash -c "$2"
}

# shellcheck disable=SC1091
source "$SCRIPT_DIR/../setup.sh"
SYNC_REPO="$REPO"
SYNC_HOME="$LOCAL_HOME"
SYNC_SSH=fake_ssh

FAIL=0
check() { # desc expected actual
    if [[ "$2" == "$3" ]]; then
        echo "  ok: $1"
    else
        echo "  FAIL: $1 (expected '$2', got '$3')"
        FAIL=1
    fi
}

install_like_setup
check "fresh install is in sync" "" "$(_host_drift somehost)"
if _check_host somehost >/dev/null; then r=pass; else r=fail; fi
check "in-sync host passes" "pass" "$r"

echo "bashrc v2" > "$REPO/.bashrc"
check "changed repo dotfile is reported" "changed: .bashrc" "$(_host_drift somehost)"
if _check_host somehost >/dev/null; then r=pass; else r=fail; fi
check "drifted host fails" "fail" "$r"
echo "bashrc v1" > "$REPO/.bashrc"

rm "$REMOTE_HOME/.local/bin/tmux_recover.sh"
check "missing script is reported" "missing: .local/bin/tmux_recover.sh" "$(_host_drift somehost)"
install_like_setup

echo "private v2" > "$LOCAL_HOME/.bashrc_private"
check "changed private config is reported" "changed: .bashrc_private" "$(_host_drift somehost)"
echo "private" > "$LOCAL_HOME/.bashrc_private"

printf 'remote-only notes\n\n%s\n# Old rules\n' "$MARKER" > "$REMOTE_HOME/.claude/CLAUDE.md"
check "stale managed CLAUDE.md block is reported" "changed: .claude/CLAUDE.md (managed block)" "$(_host_drift somehost)"

no_ssh() { return 255; }
SYNC_SSH=no_ssh
if _check_host somehost >/dev/null; then r=pass; else r=fail; fi
check "unreachable host fails" "fail" "$r"

if [[ "$FAIL" -eq 0 ]]; then
    echo "ALL PASS"
else
    echo "FAILURES"
    exit 1
fi
