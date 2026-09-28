#!/bin/bash

# `tnew`: start a new tmux session. When tmux has no sessions (e.g. after a
# reboot) and a saved layout exists, first ask whether to restore it or start
# fresh; with sessions already running it never offers a restore.
#
# tmux-resurrect only recreates panes faithfully when restoring into an empty
# server; restoring into live windows splits the saved panes into them. So this
# refuses if tmux already has sessions, picks the best backup (see
# restore_tmux.sh --auto), starts the server with a throwaway placeholder
# session, runs the restore, and removes the placeholder.
#
# Usage: tmux_recover.sh   (alias: tnew)

TMUX_CMD="${TMUX_CMD:-tmux}"
RESURRECT_RESTORE="${RESURRECT_RESTORE:-$HOME/.tmux/plugins/tmux-resurrect/scripts/restore.sh}"
RECOVER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLACEHOLDER_SESSION="__recover__"
SAVED_LAYOUT="$HOME/.tmux/resurrect/last"

_recover_tmux() {
    if _has_sessions; then
        echo "tmux already has sessions -- restoring into them would duplicate panes. Attach with: t"
        echo "To start over from a backup: tmux kill-server; tnew"
        return 1
    fi
    bash "$RECOVER_DIR/restore_tmux.sh" --auto
    $TMUX_CMD new-session -d -s "$PLACEHOLDER_SESSION"
    $TMUX_CMD run-shell "$RESURRECT_RESTORE"
    $TMUX_CMD kill-session -t "=$PLACEHOLDER_SESSION" 2>/dev/null
    echo "Restored $($TMUX_CMD list-sessions 2>/dev/null | wc -l | tr -d ' ') session(s)."
}

_has_sessions() {
    [[ -n "$($TMUX_CMD list-sessions -F '#{session_name}' 2>/dev/null)" ]]
}

# Creates the session(s) detached and sets TNEW_TARGET to the session to attach
# to (empty = most recent, used after a restore).
_tnew() {
    TNEW_TARGET=""
    if ! _has_sessions && [[ -e "$SAVED_LAYOUT" ]]; then
        local choice
        read -r -p "No tmux sessions. [r]estore saved sessions or start [n]ew? [R/n] " choice
        if [[ "$choice" != [nN]* ]]; then
            _recover_tmux
            return
        fi
    fi
    TNEW_TARGET="$(pwd | sed "s|^$HOME/|~/|")"
    $TMUX_CMD new-session -d -s "$TNEW_TARGET"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _tnew || exit 1
    if [[ -n "${TMUX:-}" ]]; then
        exec $TMUX_CMD switch-client ${TNEW_TARGET:+-t "=$TNEW_TARGET"}
    fi
    exec $TMUX_CMD attach ${TNEW_TARGET:+-t "=$TNEW_TARGET"}
fi
