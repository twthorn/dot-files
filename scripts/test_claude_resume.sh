#!/bin/bash

# Tests claude_resume.sh: the first pane of each tmux session is resumed with
# "$CLAUDE_COMMAND --resume <id>" only when it sits idle at a shell in a directory
# that has a previous Claude conversation; other panes, busy panes and dirs with
# no history are left alone. With --after-restore (panes still starting up) the
# decision comes from the saved layout: every pane that was running Claude is
# resumed (Claude may be recorded by its full path, Linux: .../node/v24/bin/claude),
# or the first pane when it sat idle and no pane in the session ran Claude. Panes
# in the same directory each get a different conversation, newest first. Before
# typing into any pane, "$CLAUDE_COMMAND --version" runs once in the foreground
# so a wrapper that logs in first (e.g. AWS SSO) asks once, not in every pane; if
# that fails nothing is resumed.
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
LOGIN_LOG="$TEST_HOME/login.log"
cat > "$TEST_HOME/bin/fake-claude" <<EOF
#!/bin/sh
if [ "\$1" = --version ]; then echo login >> "$LOGIN_LOG"; exit "\${FAKE_LOGIN_EXIT:-0}"; fi
echo "\$TMUX_PANE \$PWD \$*" >> "$RESUME_LOG"
EOF
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

FAKE_LOGIN_EXIT=1 _resume_claude >/dev/null 2>&1
check "failed login resumes nothing" "" "$(resumed)"
rm -f "$LOGIN_LOG" "$RESUME_LOG"

_resume_claude >/dev/null
check "only the idle first pane with history is resumed" \
    "$(pane_of idle:1.1) $WITH_HISTORY --resume abc;" "$(resumed)"
check "logs in once before resuming" "1" "$(wc -l < "$LOGIN_LOG" | tr -d ' ')"

rm -f "$RESUME_LOG" "$LOGIN_LOG"
$TMUX_CMD kill-session -t "=idle"
_resume_claude >/dev/null
check "no login when there is nothing to resume" "absent" "$([[ -e "$LOGIN_LOG" ]] && echo present || echo absent)"

rm -f "$RESUME_LOG"
conversation() { # dir id mmdd  (older dates are older conversations)
    touch -t "2026${3}1200" "$TEST_HOME/.claude/projects/${1//[^a-zA-Z0-9]/-}/$2.jsonl"
}
MULTI="$TEST_HOME/git/acme/multi"
mkdir -p "$MULTI" "$TEST_HOME/.claude/projects/${MULTI//[^a-zA-Z0-9]/-}"
conversation "$WITH_HISTORY" abc 0103
conversation "$WITH_HISTORY" def 0102
conversation "$WITH_HISTORY" ghi 0101
conversation "$MULTI" new3 0203
conversation "$MULTI" new2 0202
conversation "$MULTI" new1 0201
conversation "$MULTI" old0 0101
T=$'\t'
{
    echo "pane${T}wasidle${T}1${T}1${T}:*${T}1${T}t${T}:$WITH_HISTORY${T}1${T}bash${T}:"
    echo "pane${T}wasclaude${T}1${T}1${T}:*${T}1${T}t${T}:$WITH_HISTORY${T}1${T}claude${T}:claude --settings {} -r"
    echo "pane${T}wasclaudepath${T}1${T}1${T}:*${T}1${T}t${T}:$WITH_HISTORY${T}1${T}claude${T}:/home/me/.nvm/versions/node/v24.11.1/bin/claude -r"
    echo "pane${T}extra${T}1${T}1${T}:*${T}1${T}t${T}:$WITH_HISTORY${T}1${T}claude${T}:claude"
    echo "pane${T}wasvim${T}1${T}1${T}:*${T}1${T}t${T}:$WITH_HISTORY${T}1${T}vim${T}:vim notes.md"
    echo "pane${T}wasvim${T}2${T}0${T}:${T}1${T}t${T}:$WITH_HISTORY${T}1${T}bash${T}:"
    echo "pane${T}multi${T}1${T}1${T}:*${T}1${T}t${T}:$MULTI${T}1${T}bash${T}:"
    echo "pane${T}multi${T}1${T}1${T}:*${T}2${T}t${T}:$MULTI${T}0${T}claude${T}:claude --continue"
    echo "pane${T}multi${T}1${T}1${T}:*${T}3${T}t${T}:$MULTI${T}0${T}claude${T}:claude"
    echo "pane${T}multi${T}2${T}0${T}:${T}1${T}t${T}:$MULTI${T}1${T}claude${T}:claude -r"
} > "$TEST_HOME/.tmux/resurrect/last"
tmux -L "$SOCK" kill-server 2>/dev/null
for s in wasidle wasclaude wasclaudepath extra wasvim; do
    $TMUX_CMD new-session -d -s "$s" -c "$WITH_HISTORY"
done
$TMUX_CMD new-window -d -t wasvim:2 -c "$WITH_HISTORY"
$TMUX_CMD new-session -d -s multi -c "$MULTI"
$TMUX_CMD split-window -d -t multi:1.1 -c "$MULTI"
$TMUX_CMD split-window -d -t multi:1.2 -c "$MULTI"
$TMUX_CMD new-window -d -t multi:2 -c "$MULTI"
sleep 0.5

_resume_claude --after-restore >/dev/null
check "after restore: every pane that ran claude, and idle first panes, get the newest conversations; a pane with no conversation left and panes restoring another program are skipped" \
    "$({
        echo "$(pane_of wasidle:1.1) $WITH_HISTORY --resume abc"
        echo "$(pane_of wasclaude:1.1) $WITH_HISTORY --resume def"
        echo "$(pane_of wasclaudepath:1.1) $WITH_HISTORY --resume ghi"
        echo "$(pane_of multi:1.2) $MULTI --resume new3"
        echo "$(pane_of multi:1.3) $MULTI --resume new2"
        echo "$(pane_of multi:2.1) $MULTI --resume new1"
    } | sort | tr '\n' ';')" \
    "$(resumed)"

if [[ "$FAIL" -eq 0 ]]; then
    echo "ALL PASS"
else
    echo "FAILURES"
    exit 1
fi
