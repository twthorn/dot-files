#!/bin/bash

# Tests claude_resume.sh: the first pane of each tmux session is resumed with
# "$CLAUDE_COMMAND --continue" only when it sits idle at a shell in a directory
# that has a previous Claude conversation; other panes, busy panes and dirs with
# no history are left alone. With --after-restore (panes still starting up) the
# decision comes from what the first pane was running in the saved layout.
# Runs a throwaway tmux server (-L) and HOME; the fake claude logs its pane.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TEST_HOME="$(cd "$(mktemp -d)" && pwd -P)"
SOCK="claudetest_$$"
CONF="$TEST_HOME/tmux.conf"
printf 'set -g base-index 1\nsetw -g pane-base-index 1\nset -g default-shell /bin/bash\n' > "$CONF"
export HOME="$TEST_HOME"
export TMUX_CMD="tmux -L $SOCK -f $CONF"
unset TMUX

cleanup() { tmux -L "$SOCK" kill-server 2>/dev/null; rm -rf "$TEST_HOME"; }
trap cleanup EXIT

WITH_HISTORY="$TEST_HOME/git/acme/api"
NO_HISTORY="$TEST_HOME/git/acme/web"
mkdir -p "$WITH_HISTORY" "$NO_HISTORY" "$TEST_HOME/bin" "$TEST_HOME/.tmux/resurrect"
mkdir -p "$TEST_HOME/.claude/projects/${WITH_HISTORY//[^a-zA-Z0-9]/-}"
touch "$TEST_HOME/.claude/projects/${WITH_HISTORY//[^a-zA-Z0-9]/-}/abc.jsonl"
RESUME_LOG="$TEST_HOME/resumed.log"
printf '#!/bin/sh\necho "$TMUX_PANE $PWD $*" >> %s\n' "$RESUME_LOG" > "$TEST_HOME/bin/fake-claude"
chmod +x "$TEST_HOME/bin/fake-claude"
export CLAUDE_COMMAND="$TEST_HOME/bin/fake-claude"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/claude_resume.sh"

FAIL=0
check() { # desc expected actual
    if [[ "$2" == "$3" ]]; then
        echo "  ok: $1"
    else
        echo "  FAIL: $1 (expected '$2', got '$3')"
        FAIL=1
    fi
}
pane_of() { $TMUX_CMD display-message -p -t "$1" '#{pane_id}'; }
resumed() { # wait for the panes' shells to run what was typed, then list "pane dir args"
    sleep 1
    sort "$RESUME_LOG" 2>/dev/null | tr '\n' ';'
}

$TMUX_CMD new-session -d -s idle -c "$WITH_HISTORY"
$TMUX_CMD new-window -d -t idle: -c "$WITH_HISTORY"
$TMUX_CMD new-session -d -s nohistory -c "$NO_HISTORY"
$TMUX_CMD new-session -d -s busy -c "$WITH_HISTORY" 'sleep 300'
sleep 0.5

_resume_claude >/dev/null
check "only the idle first pane with history is resumed" \
    "$(pane_of idle:1.1) $WITH_HISTORY --continue;" "$(resumed)"

rm -f "$RESUME_LOG"
T=$'\t'
{
    echo "pane${T}wasidle${T}1${T}1${T}:*${T}1${T}t${T}:$WITH_HISTORY${T}1${T}bash${T}:"
    echo "pane${T}wasclaude${T}1${T}1${T}:*${T}1${T}t${T}:$WITH_HISTORY${T}1${T}claude${T}:claude --settings {} -r"
    echo "pane${T}wasvim${T}1${T}1${T}:*${T}1${T}t${T}:$WITH_HISTORY${T}1${T}vim${T}:vim notes.md"
    echo "pane${T}wasvim${T}2${T}0${T}:${T}1${T}t${T}:$WITH_HISTORY${T}1${T}bash${T}:"
} > "$TEST_HOME/.tmux/resurrect/last"
tmux -L "$SOCK" kill-server 2>/dev/null
for s in wasidle wasclaude wasvim; do
    $TMUX_CMD new-session -d -s "$s" -c "$WITH_HISTORY"
done
$TMUX_CMD new-window -d -t wasvim:2 -c "$WITH_HISTORY"
sleep 0.5

_resume_claude --after-restore >/dev/null
check "after restore: first panes that were idle or in claude are resumed, not ones restoring another program" \
    "$(printf '%s\n' "$(pane_of wasclaude:1.1) $WITH_HISTORY --continue" "$(pane_of wasidle:1.1) $WITH_HISTORY --continue" | sort | tr '\n' ';')" \
    "$(resumed)"

if [[ "$FAIL" -eq 0 ]]; then
    echo "ALL PASS"
else
    echo "FAILURES"
    exit 1
fi
