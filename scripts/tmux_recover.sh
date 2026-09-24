#!/bin/bash

# Recover tmux after a reboot: start a fresh server, restore the saved layout
# exactly once, then attach.
#
# tmux-resurrect only recreates panes faithfully when restoring into an empty
# server; restoring into live windows splits the saved panes into them. So this
# refuses if a server is already running, picks the best backup (see
# restore_tmux.sh --auto), starts the server with a throwaway placeholder
# session, runs the restore, and removes the placeholder.
#
# Usage: tmux_recover.sh   (alias: trecover)

TMUX_CMD="${TMUX_CMD:-tmux}"
RESURRECT_RESTORE="${RESURRECT_RESTORE:-$HOME/.tmux/plugins/tmux-resurrect/scripts/restore.sh}"
RECOVER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLACEHOLDER_SESSION="__recover__"

_recover_tmux() {
    if $TMUX_CMD list-sessions &>/dev/null; then
        echo "tmux is already running -- restoring into it would duplicate panes. Attach with: t"
        echo "To start over from a backup: tmux kill-server; trecover"
        return 1
    fi
    bash "$RECOVER_DIR/restore_tmux.sh" --auto
    $TMUX_CMD new-session -d -s "$PLACEHOLDER_SESSION"
    $TMUX_CMD run-shell "$RESURRECT_RESTORE"
    $TMUX_CMD kill-session -t "=$PLACEHOLDER_SESSION" 2>/dev/null
    echo "Restored $($TMUX_CMD list-sessions 2>/dev/null | wc -l | tr -d ' ') session(s)."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _recover_tmux && exec $TMUX_CMD attach
fi
