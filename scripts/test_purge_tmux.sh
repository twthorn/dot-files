#!/bin/bash

# Tests for purge_tmux.sh session-classification logic.
# Runs against a throwaway tmux server (-L purgetest_$$) so it never touches
# real sessions. Exercises the real code paths in purge_tmux.sh by sourcing it.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SOCK="purgetest_$$"
export TMUX_CMD="tmux -L $SOCK"
source "$SCRIPT_DIR/purge_tmux.sh"

cleanup() { tmux -L "$SOCK" kill-server 2>/dev/null; }
trap cleanup EXIT

pass=0; fail=0
ok()   { echo "  PASS: $1"; pass=$(( pass + 1 )); }
bad()  { echo "  FAIL: $1"; fail=$(( fail + 1 )); }

assert_blank() {
    if _session_is_blank "$1"; then ok "$2 (blank)"; else bad "$2 -- expected blank, got used"; fi
}
assert_used() {
    if _session_is_blank "$1"; then bad "$2 -- expected used, got blank"; else ok "$2 (used)"; fi
}

# _scrollback_has_real_activity works on raw text; test it directly with the
# exact captures observed from live panes (ground truth), no tmux needed.
echo "== scrollback classifier (fixtures) =="

feed() { printf '%s\n' "$1" | _scrollback_has_real_activity; }

REAL_RELOAD_NOISE='tthornton at tthornto-ltmk3dt in ~/scratch
$  exec bash --norc --noprofile ~/.local/bin/tmux_shell.sh
tthornton at tthornto-ltmk3dt in ~/scratch
$  exec bash --norc --noprofile ~/.local/bin/tmux_shell.sh
pyenv: cannot rehash: couldn'"'"'t acquire lock /Users/tthornton/.pyenv/shims/.pyenv-shim for 60 seconds. Last error message:
/opt/homebrew/Cellar/pyenv/2.6.23/libexec/pyenv-rehash: line 22: /Users/tthornton/.pyenv/shims/.pyenv-shim: cannot overwrite existing file
tthornton at tthornto-ltmk3dt in ~/scratch
$'

if feed "$REAL_RELOAD_NOISE"; then bad "real reload+pyenv scrollback -- should be noise"; else ok "real reload+pyenv scrollback is noise"; fi

REAL_USED='tthornton at tthornto-ltmk3dt in ~/scratch
$ echo hello_world_real_output
hello_world_real_output
tthornton at tthornto-ltmk3dt in ~/scratch
$'
if feed "$REAL_USED"; then ok "real user command is activity"; else bad "real user command -- should be activity"; fi

if feed '' ; then bad "empty scrollback -- should be noise"; else ok "empty scrollback is noise"; fi

# Live sessions on the throwaway server exercise _session_is_blank end to end.
echo "== live session classifier =="

TS="$TMUX_CMD"
$TS kill-server 2>/dev/null
$TS new-session -d -s blank      -x 100 -y 30
$TS new-session -d -s reloadonly -x 100 -y 30
$TS new-session -d -s used       -x 100 -y 30
$TS new-session -d -s multiblank -x 100 -y 30
$TS new-session -d -s oneused    -x 100 -y 30

# Give shells time to render a first prompt (pyenv lock is cleared, so ~1s).
sleep 2
$TS send-keys -t reloadonly " exec bash --norc --noprofile ~/.local/bin/tmux_shell.sh" C-m
$TS send-keys -t used       "echo hello_world_real_output" C-m
$TS split-window -t multiblank -d
$TS split-window -t multiblank -d
$TS split-window -t oneused    -d
$TS send-keys -t oneused "echo touched_second_pane" C-m
sleep 3

assert_blank blank      "single fresh shell"
assert_blank reloadonly "shell with only reload command"
assert_used  used       "shell with a real command"
assert_blank multiblank "many panes, all fresh shells"
assert_used  oneused    "many panes, one has real activity"

echo
echo "Results: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
