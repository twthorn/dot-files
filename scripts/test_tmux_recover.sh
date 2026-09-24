#!/bin/bash

# Tests tmux_recover.sh: starting a fresh server and restoring the saved layout
# must reproduce each window's pane count exactly (no duplicate splits), leave no
# placeholder session behind, and refuse to restore into an already-running
# server. Runs the real tmux-resurrect restore against a throwaway server
# (-L recovertest_$$) and a throwaway HOME so real sessions/backups are untouched.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_RESTORE="$HOME/.tmux/plugins/tmux-resurrect/scripts/restore.sh"
[[ -x "$REAL_RESTORE" ]] || { echo "SKIP: tmux-resurrect not installed"; exit 0; }

TEST_HOME="$(mktemp -d)"
SOCK="recovertest_$$"
CONF="$TEST_HOME/tmux.conf"
printf 'set -g base-index 1\nsetw -g pane-base-index 1\n' > "$CONF"
export HOME="$TEST_HOME"
export TMUX_CMD="tmux -L $SOCK -f $CONF"
export RESURRECT_RESTORE="$REAL_RESTORE"
unset TMUX

cleanup() { tmux -L "$SOCK" kill-server 2>/dev/null; rm -rf "$TEST_HOME"; }
trap cleanup EXIT

SAVE_DIR="$TEST_HOME/.tmux/resurrect"
mkdir -p "$SAVE_DIR"
T=$'\t'
{
    echo "pane${T}alpha${T}1${T}1${T}:*${T}1${T}t${T}:$TEST_HOME${T}1${T}bash${T}:"
    echo "pane${T}alpha${T}2${T}0${T}:${T}1${T}t${T}:$TEST_HOME${T}1${T}bash${T}:"
    echo "pane${T}alpha${T}2${T}0${T}:${T}2${T}t${T}:$TEST_HOME${T}0${T}bash${T}:"
    echo "pane${T}beta${T}1${T}1${T}:*${T}1${T}t${T}:$TEST_HOME${T}1${T}bash${T}:"
    echo "window${T}alpha${T}1${T}:one${T}1${T}:*${T}tiled${T}:"
    echo "window${T}alpha${T}2${T}:two${T}0${T}:${T}tiled${T}:"
    echo "window${T}beta${T}1${T}:one${T}1${T}:*${T}tiled${T}:"
    echo "state${T}alpha${T}beta"
} > "$SAVE_DIR/tmux_resurrect_20260101T000000.txt"
ln -sf tmux_resurrect_20260101T000000.txt "$SAVE_DIR/last"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/tmux_recover.sh"

FAIL=0
check() { # desc expected actual
    if [[ "$2" == "$3" ]]; then
        echo "  ok: $1"
    else
        echo "  FAIL: $1 (expected '$2', got '$3')"
        FAIL=1
    fi
}
layout() { $TMUX_CMD list-panes -a -F '#{session_name}:#{window_index}' | sort | uniq -c | awk '{print $2"="$1}' | tr '\n' ' ' | sed 's/ *$//'; }

_recover_tmux >/dev/null
check "restore reproduces saved pane counts" "alpha:1=1 alpha:2=2 beta:1=1" "$(layout)"
check "no placeholder session left"          "alpha beta" "$($TMUX_CMD list-sessions -F '#{session_name}' | sort | tr '\n' ' ' | sed 's/ *$//')"

if _recover_tmux >/dev/null; then r=ran; else r=refused; fi
check "refuses when server already running"  "refused" "$r"
check "second attempt adds no panes"         "alpha:1=1 alpha:2=2 beta:1=1" "$(layout)"

if [[ "$FAIL" -eq 0 ]]; then
    echo "ALL PASS"
else
    echo "FAILURES"
    exit 1
fi
