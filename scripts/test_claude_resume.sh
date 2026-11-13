#!/bin/bash

# Tests claude_resume.sh (`crestore [N]`): run inside a tmux session, it resumes
# that session's Claude conversations ("$CLAUDE_COMMAND --resume <id>", newest
# first) into the panes that were running Claude in the saved layout; with none
# recorded, into the pane it was run from. N limits (or, with extra idle panes,
# extends) how many come back; the default is one per recorded Claude pane.
# Only panes idle at a shell are typed into, so it is safe to rerun. Before typing
# into any pane, "$CLAUDE_COMMAND --version" runs once in the foreground so a
# wrapper that logs in first (e.g. AWS SSO) asks once; if that fails nothing is
# resumed. Claude may be recorded by its full path (Linux: .../node/v24/bin/claude).
# Runs a throwaway tmux server (-L) and HOME; the fake claude logs its pane.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TEST_HOME="$(cd "$(mktemp -d)" && pwd -P)"
SOCK="claudetest_$$"
CONF="$TEST_HOME/tmux.conf"
printf 'set -g base-index 1\nsetw -g pane-base-index 1\nset -g default-shell /bin/bash\n' > "$CONF"
export HOME="$TEST_HOME"
export TMUX_CMD="tmux -L $SOCK -f $CONF"
unset TMUX TMUX_PANE

cleanup() { tmux -L "$SOCK" kill-server 2>/dev/null; rm -rf "$TEST_HOME"; }
trap cleanup EXIT

MULTI="$TEST_HOME/git/acme/multi"
PLAIN="$TEST_HOME/git/acme/plain"
NO_HISTORY="$TEST_HOME/git/acme/web"
mkdir -p "$MULTI" "$PLAIN" "$NO_HISTORY" "$TEST_HOME/bin" "$TEST_HOME/.tmux/resurrect"
conversation() { # dir id mmdd  (older dates are older conversations)
    local project="$TEST_HOME/.claude/projects/${1//[^a-zA-Z0-9]/-}"
    mkdir -p "$project"
    touch -t "2026${3}1200" "$project/$2.jsonl"
}
conversation "$MULTI" new3 0203
conversation "$MULTI" new2 0202
conversation "$MULTI" new1 0201
conversation "$MULTI" old0 0101
conversation "$PLAIN" abc 0103
RESUME_LOG="$TEST_HOME/resumed.log"
LOGIN_LOG="$TEST_HOME/login.log"
cat > "$TEST_HOME/bin/fake-claude" <<EOF
#!/bin/sh
if [ "\$1" = --version ]; then echo login >> "$LOGIN_LOG"; exit "\${FAKE_LOGIN_EXIT:-0}"; fi
echo "\$TMUX_PANE \$PWD \$*" >> "$RESUME_LOG"
EOF
chmod +x "$TEST_HOME/bin/fake-claude"
export CLAUDE_COMMAND="$TEST_HOME/bin/fake-claude"

T=$'\t'
{
    echo "pane${T}multi${T}1${T}1${T}:*${T}1${T}t${T}:$MULTI${T}1${T}bash${T}:"
    echo "pane${T}multi${T}1${T}1${T}:*${T}2${T}t${T}:$MULTI${T}0${T}claude${T}:claude --settings {} -r"
    echo "pane${T}multi${T}1${T}1${T}:*${T}3${T}t${T}:$MULTI${T}0${T}claude${T}:/home/me/.nvm/versions/node/v24.11.1/bin/claude -r"
    echo "pane${T}multi${T}2${T}0${T}:${T}1${T}t${T}:$MULTI${T}1${T}claude${T}:claude"
    echo "pane${T}multi${T}3${T}0${T}:${T}1${T}t${T}:$MULTI${T}1${T}vim${T}:vim notes.md"
    echo "pane${T}plain${T}1${T}1${T}:*${T}1${T}t${T}:$PLAIN${T}1${T}bash${T}:"
    echo "pane${T}plain${T}1${T}1${T}:*${T}2${T}t${T}:$PLAIN${T}0${T}bash${T}:"
} > "$TEST_HOME/.tmux/resurrect/last"

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
expect() { # dir "target id"... -> the resumed() form
    local dir="$1" pair; shift
    for pair in "$@"; do echo "$(pane_of "${pair% *}") $dir --resume ${pair#* }"; done | sort | tr '\n' ';'
}
crestore_from() { # pane [N]
    local pane="$1"; shift
    rm -f "$RESUME_LOG" "$LOGIN_LOG"
    TMUX_PANE="$(pane_of "$pane")" _crestore "$@"
}

$TMUX_CMD new-session -d -s multi -c "$MULTI"
$TMUX_CMD split-window -d -t multi:1.1 -c "$MULTI"
$TMUX_CMD split-window -d -t multi:1.2 -c "$MULTI"
$TMUX_CMD new-window -d -t multi:2 -c "$MULTI"
$TMUX_CMD new-window -d -t multi:3 -c "$MULTI" 'sleep 300'
$TMUX_CMD new-session -d -s plain -c "$PLAIN"
$TMUX_CMD split-window -d -t plain:1.1 -c "$PLAIN"
$TMUX_CMD new-session -d -s nohistory -c "$NO_HISTORY"
sleep 0.5

rm -f "$RESUME_LOG"
if _crestore >/dev/null 2>&1; then r=ran; else r=refused; fi
check "outside tmux it refuses" "refused" "$r"
check "outside tmux nothing is resumed" "" "$(resumed)"

FAKE_LOGIN_EXIT=1 crestore_from multi:1.1 >/dev/null 2>&1
check "failed login resumes nothing" "" "$(resumed)"

crestore_from multi:1.1 >/dev/null
check "default: every pane that ran claude gets its own conversation, newest first" \
    "$(expect "$MULTI" "multi:1.2 new3" "multi:1.3 new2" "multi:2.1 new1")" "$(resumed)"
check "logs in once before resuming" "1" "$(wc -l < "$LOGIN_LOG" | tr -d ' ')"

crestore_from multi:1.1 1 >/dev/null
check "N=1: only the first claude pane and the newest conversation" \
    "$(expect "$MULTI" "multi:1.2 new3")" "$(resumed)"

crestore_from multi:1.1 9 >/dev/null
check "N beyond the claude panes spills into other idle panes, skips the busy one, stops when conversations run out" \
    "$(expect "$MULTI" "multi:1.2 new3" "multi:1.3 new2" "multi:2.1 new1" "multi:1.1 old0")" "$(resumed)"

$TMUX_CMD respawn-pane -k -t multi:1.3 'sleep 300'
sleep 0.3
crestore_from multi:1.1 >/dev/null
check "a claude pane that is busy now is left alone" \
    "$(expect "$MULTI" "multi:1.2 new3" "multi:2.1 new2")" "$(resumed)"

crestore_from plain:1.2 >/dev/null
check "no claude pane recorded: the pane it was run from gets the newest conversation" \
    "$(expect "$PLAIN" "plain:1.2 abc")" "$(resumed)"

crestore_from nohistory:1.1 >/dev/null
check "no history: nothing resumed" "" "$(resumed)"
check "no history: no login" "absent" "$([[ -e "$LOGIN_LOG" ]] && echo present || echo absent)"

if [[ "$FAIL" -eq 0 ]]; then
    echo "ALL PASS"
else
    echo "FAILURES"
    exit 1
fi
