#!/bin/bash

# `crestore [N]`: resume this tmux session's Claude Code conversations. Run it
# inside a session: it types "$CLAUDE_COMMAND --resume <id>" into the panes that
# were running Claude when the layout was saved (tmux-resurrect), newest
# conversation first, so three Claude panes in one repo come back as the three
# most recent conversations there. With no Claude pane recorded it uses the pane
# it was run from. N caps how many come back (default: one per recorded Claude
# pane); an N above that spills into the session's other idle panes.
#
# Opt-in per session on purpose: after a restore, resuming Claude in every
# session at once ran the machine out of memory. tnew restores the panes only
# and leaves this to you.
#
# Only panes idle at a shell are typed into, so it is safe to rerun. Before typing
# into any pane it runs "$CLAUDE_COMMAND --version" once in the foreground, so a
# wrapper that logs in first (e.g. AWS SSO) asks here once and every pane then
# reuses that login, instead of each pane asking on its own.
#
# CLAUDE_COMMAND defaults to claude; override it in ~/.bashrc_private.
#
# Usage: claude_resume.sh [N]   (alias: crestore)

TMUX_CMD="${TMUX_CMD:-tmux}"
SAVED_LAYOUT="$HOME/.tmux/resurrect/last"
if [[ -z "${CLAUDE_COMMAND:-}" && -f "$HOME/.bashrc_private" ]]; then
    # shellcheck disable=SC1091
    source "$HOME/.bashrc_private"
fi
CLAUDE_COMMAND="${CLAUDE_COMMAND:-claude}"
TAB=$'\t'

_conversations_newest_first() { # dir
    ls -t "$HOME/.claude/projects/${1//[^a-zA-Z0-9]/-}"/*.jsonl 2>/dev/null | sed 's|.*/||; s|\.jsonl$||'
}

_is_shell() { # command
    [[ "$1" =~ ^-?(bash|zsh|sh|fish)$ ]]
}

# "window.pane" of each pane in the session that was running claude (possibly by
# full path) when the layout was saved, in layout order.
_saved_claude_panes() { # session
    awk -F'\t' -v session="$1" '
        $1 == "pane" && $2 == session {
            split(substr($11, 2), words, " ")
            n = split(words[1], path, "/")
            if (path[n] == "claude") print $3 "." $6
        }' "$SAVED_LAYOUT" 2>/dev/null
}

# "pane_id<TAB>window.pane" of each pane in the session idle at a shell.
_idle_panes() { # session
    local pane_id label command
    while IFS="$TAB" read -r pane_id label command; do
        _is_shell "$command" && echo "$pane_id$TAB$label"
    done < <($TMUX_CMD list-panes -s -t "=$1" -F "#{pane_id}${TAB}#{window_index}.#{pane_index}${TAB}#{pane_current_command}")
}

# Idle panes to type into, in preference order: recorded claude panes, the pane
# this was run from, then the rest. Sets TARGETS (pane ids) and DEFAULT_COUNT.
_choose_targets() { # session
    local idle label pane_id
    idle=$(_idle_panes "$1")
    TARGETS=()
    DEFAULT_COUNT=0
    while IFS= read -r label; do
        [[ -n "$label" ]] || continue
        pane_id=$(awk -F'\t' -v label="$label" '$2 == label { print $1 }' <<<"$idle")
        [[ -n "$pane_id" ]] && TARGETS+=("$pane_id") && DEFAULT_COUNT=$((DEFAULT_COUNT + 1))
    done < <(_saved_claude_panes "$1")
    [[ "$DEFAULT_COUNT" -eq 0 ]] && DEFAULT_COUNT=1
    TARGETS+=("$TMUX_PANE")
    while IFS="$TAB" read -r pane_id label; do
        [[ -n "$pane_id" ]] && TARGETS+=("$pane_id")
    done <<<"$idle"
    local -a unique=()
    while IFS= read -r pane_id; do unique+=("$pane_id"); done < <(printf '%s\n' "${TARGETS[@]}" | awk '!seen[$0]++')
    TARGETS=("${unique[@]}")
}

_crestore() { # [N]
    local session dir count
    if [[ -z "${TMUX_PANE:-}" ]] || ! session=$($TMUX_CMD display-message -p -t "$TMUX_PANE" '#{session_name}' 2>/dev/null); then
        echo "crestore: run this inside a tmux session" >&2
        return 1
    fi
    dir=$($TMUX_CMD display-message -p -t "$TMUX_PANE" '#{pane_current_path}')
    local -a ids=()
    local id
    while IFS= read -r id; do ids+=("$id"); done < <(_conversations_newest_first "$dir")
    if [[ ${#ids[@]} -eq 0 ]]; then
        echo "No Claude conversations for ${dir/#$HOME/~}"
        return 0
    fi

    local -a TARGETS
    local DEFAULT_COUNT
    _choose_targets "$session"
    count="${1:-$DEFAULT_COUNT}"
    (( count > ${#TARGETS[@]} )) && count=${#TARGETS[@]}
    (( count > ${#ids[@]} )) && count=${#ids[@]}
    if (( count < ${1:-0} )); then
        echo "Resuming $count (${#ids[@]} conversation(s) for ${dir/#$HOME/~}, ${#TARGETS[@]} idle pane(s) in $session)"
    fi

    if ! $CLAUDE_COMMAND --version; then
        echo "Could not start $CLAUDE_COMMAND (login failed?); not resuming Claude. Retry with: crestore"
        return 1
    fi
    local i
    for (( i = 0; i < count; i++ )); do
        $TMUX_CMD send-keys -t "${TARGETS[i]}" "$CLAUDE_COMMAND --resume ${ids[i]}" Enter
        echo "Resumed Claude in $session pane $($TMUX_CMD display-message -p -t "${TARGETS[i]}" '#{window_index}.#{pane_index}') (${ids[i]})"
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _crestore "$@"
fi
