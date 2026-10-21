#!/bin/bash

# `tclaude`: resume Claude Code ("$CLAUDE_COMMAND --continue") in the first pane
# of every tmux session whose directory has a previous Claude conversation. Only
# panes idle at a shell are touched, so it is safe to rerun at any time.
#
# tnew runs this right after restoring a saved layout (--after-restore). The
# panes are still starting up then, so instead of their live state it uses what
# each first pane was running when the layout was saved: idle or Claude gets
# resumed, anything else (vim, less, ...) is being restored by tmux-resurrect.
#
# CLAUDE_COMMAND defaults to claude; override it in ~/.bashrc_private.
#
# Usage: claude_resume.sh [--after-restore]   (alias: tclaude)

TMUX_CMD="${TMUX_CMD:-tmux}"
SAVED_LAYOUT="$HOME/.tmux/resurrect/last"
if [[ -z "${CLAUDE_COMMAND:-}" && -f "$HOME/.bashrc_private" ]]; then
    # shellcheck disable=SC1091
    source "$HOME/.bashrc_private"
fi
CLAUDE_COMMAND="${CLAUDE_COMMAND:-claude}"
TAB=$'\t'

_has_claude_history() { # dir
    compgen -G "$HOME/.claude/projects/${1//[^a-zA-Z0-9]/-}/*.jsonl" >/dev/null
}

_is_shell() { # command
    [[ "$1" =~ ^-?(bash|zsh|sh|fish)$ ]]
}

_saved_first_pane_command() { # session
    awk -F'\t' -v session="$1" '$1 == "pane" && $2 == session { print $3 "\t" $6 "\t" substr($11, 2) }' "$SAVED_LAYOUT" 2>/dev/null \
        | sort -t "$TAB" -k1,1n -k2,2n | head -1 | cut -f3
}

_was_idle_or_claude() { # saved command
    [[ -z "$1" || "$1" == claude* ]]
}

_resume_claude() { # [--after-restore]
    local session pane_id command dir
    while IFS= read -r session; do
        IFS="$TAB" read -r pane_id command dir < <(
            $TMUX_CMD list-panes -s -t "=$session" -F "#{pane_id}${TAB}#{pane_current_command}${TAB}#{pane_current_path}" | head -1)
        if [[ "${1:-}" == --after-restore ]]; then
            _was_idle_or_claude "$(_saved_first_pane_command "$session")" || continue
        else
            _is_shell "$command" || continue
        fi
        _has_claude_history "$dir" || continue
        $TMUX_CMD send-keys -t "$pane_id" "$CLAUDE_COMMAND --continue" Enter
        echo "Resumed Claude in $session (${dir/#$HOME/~})"
    done < <($TMUX_CMD list-sessions -F '#{session_name}' 2>/dev/null)
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _resume_claude "$@"
fi
