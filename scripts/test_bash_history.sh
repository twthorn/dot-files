#!/bin/bash

# Tests .bash_history_setup: every shell starts from the global history unless it
# is a reloaded shell in the same pane of the same tmux server, which keeps its
# own history. A new tmux server (e.g. after a reboot + restore) reuses pane ids
# like %5, so files left by an older server must not be picked up. Session files
# untouched for over 30 days are pruned. Runs against a throwaway HOME.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_FILE="$SCRIPT_DIR/../.bash_history_setup"
TEST_HOME="$(mktemp -d)"
trap 'rm -rf "$TEST_HOME"' EXIT
mkdir -p "$TEST_HOME/.bash_history.d"
echo "global-cmd" > "$TEST_HOME/.bash_history"

FAIL=0
check() { # desc expected actual
    if [[ "$2" == "$3" ]]; then
        echo "  ok: $1"
    else
        echo "  FAIL: $1 (expected '$2', got '$3')"
        FAIL=1
    fi
}
# Start a shell the way .bashrc would and print the history it starts with.
shell_history() { # tmux-env pane
    HOME="$TEST_HOME" TMUX="$1" TMUX_PANE="$2" bash -c 'source "$1"; cat "$HISTFILE"' _ "$SETUP_FILE"
}

echo "old-pane-cmd" > "$TEST_HOME/.bash_history.d/tmux__5"
echo "old-server-cmd" > "$TEST_HOME/.bash_history.d/tmux_111__5"
check "new tmux server pane starts from global" "global-cmd" "$(shell_history /tmp/tmux-501/default,222,0 %5)"

echo "own-cmd" > "$TEST_HOME/.bash_history.d/tmux_222__5"
check "reloaded shell in same pane keeps its history" "own-cmd" "$(shell_history /tmp/tmux-501/default,222,0 %5)"

check "shell outside tmux starts from global" "global-cmd" "$(shell_history "" "")"

touch -t 200001010000 "$TEST_HOME/.bash_history.d/tmux_111__5"
shell_history /tmp/tmux-501/default,222,0 %6 >/dev/null
check "stale session file pruned" "gone" "$([[ -e "$TEST_HOME/.bash_history.d/tmux_111__5" ]] && echo present || echo gone)"
check "recent session file kept" "present" "$([[ -e "$TEST_HOME/.bash_history.d/tmux_222__5" ]] && echo present || echo gone)"

if [[ "$FAIL" -eq 0 ]]; then
    echo "ALL PASS"
else
    echo "FAILURES"
    exit 1
fi
