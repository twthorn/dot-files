#!/bin/bash

# `tclaude`: resume Claude Code in tmux panes that have a previous conversation.
# Live, it looks at the first pane of every session and types
# "$CLAUDE_COMMAND --resume <id>" into the ones idle at a shell, so it is safe to
# rerun at any time.
#
# tnew runs this right after restoring a saved layout (--after-restore). The
# panes are still starting up then, so instead of their live state it uses the
# saved layout: every pane that was running Claude is resumed, and a session
# with no such pane gets Claude in its first pane if that sat idle at a shell.
# Anything else (vim, less, ...) is being restored by tmux-resurrect.
#
# Panes in the same directory each get their own conversation, newest first, so
# three Claude panes in one repo come back as the three most recent conversations
# there rather than three copies of the latest one. A pane with no conversation
# left over is skipped.
#
# Before typing into any pane it runs "$CLAUDE_COMMAND --version" once in the
# foreground, so a wrapper that logs in first (e.g. AWS SSO) asks here once and
# every pane then reuses that login, instead of each pane asking on its own.
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

_project_dir() { # dir
    echo "$HOME/.claude/projects/${1//[^a-zA-Z0-9]/-}"
}

_has_claude_history() { # dir
    compgen -G "$(_project_dir "$1")/*.jsonl" >/dev/null
}

_conversations_newest_first() { # dir
    ls -t "$(_project_dir "$1")"/*.jsonl 2>/dev/null | sed 's|.*/||; s|\.jsonl$||'
}

_is_shell() { # command
    [[ "$1" =~ ^-?(bash|zsh|sh|fish)$ ]]
}

# Live targets, "pane_id<TAB>label<TAB>dir": the first pane of each session when
# it sits idle at a shell.
_live_targets() {
    local session pane_id command dir
    while IFS= read -r session; do
        IFS="$TAB" read -r pane_id command dir < <(
            $TMUX_CMD list-panes -s -t "=$session" -F "#{pane_id}${TAB}#{pane_current_command}${TAB}#{pane_current_path}" | head -1)
        _is_shell "$command" || continue
        echo "$pane_id$TAB$session$TAB$dir"
    done < <($TMUX_CMD list-sessions -F '#{session_name}' 2>/dev/null)
}

# Saved panes to resume, "session<TAB>window<TAB>pane<TAB>dir", in layout order:
# every pane whose command was claude (possibly by full path), else the first
# pane of the session when it was idle (no command).
_saved_resume_panes() {
    awk -F'\t' '
        function flush() { if (session != "" && claude_panes == 0 && first_idle) print first }
        $1 == "pane" {
            if ($2 != session) {
                flush()
                session = $2; claude_panes = 0
                first = $2 "\t" $3 "\t" $6 "\t" substr($8, 2)
                first_idle = (substr($11, 2) == "")
            }
            split(substr($11, 2), words, " ")
            n = split(words[1], path, "/")
            if (path[n] == "claude") { claude_panes++; print $2 "\t" $3 "\t" $6 "\t" substr($8, 2) }
        }
        END { flush() }' "$SAVED_LAYOUT" 2>/dev/null
}

# After a restore, "pane_id<TAB>label<TAB>dir" for each saved pane that came back.
_restored_targets() {
    local session window pane dir pane_id
    while IFS="$TAB" read -r session window pane dir; do
        pane_id=$($TMUX_CMD display-message -p -t "=$session:$window.$pane" '#{pane_id}' 2>/dev/null) || continue
        echo "$pane_id$TAB$session:$window.$pane$TAB$dir"
    done < <(_saved_resume_panes)
}

_resume_claude() { # [--after-restore]
    local target pane_id label dir
    local -a targets=()
    while IFS= read -r target; do
        IFS="$TAB" read -r pane_id label dir <<<"$target"
        _has_claude_history "$dir" && targets+=("$target")
    done < <(if [[ "${1:-}" == --after-restore ]]; then _restored_targets; else _live_targets; fi)

    [[ ${#targets[@]} -gt 0 ]] || return 0
    if ! $CLAUDE_COMMAND --version; then
        echo "Could not start $CLAUDE_COMMAND (login failed?); not resuming Claude. Retry with: tclaude"
        return 1
    fi
    local id next
    local -a ids
    while IFS= read -r dir; do
        ids=()
        while IFS= read -r id; do ids+=("$id"); done < <(_conversations_newest_first "$dir")
        next=0
        while IFS="$TAB" read -r pane_id label _; do
            if (( next < ${#ids[@]} )); then
                $TMUX_CMD send-keys -t "$pane_id" "$CLAUDE_COMMAND --resume ${ids[next]}" Enter
                echo "Resumed Claude in $label (${dir/#$HOME/~})"
            else
                echo "No further conversation to resume in $label (${dir/#$HOME/~})"
            fi
            next=$((next + 1))
        done < <(printf '%s\n' "${targets[@]}" | awk -F'\t' -v dir="$dir" '$3 == dir')
    done < <(printf '%s\n' "${targets[@]}" | cut -f3 | awk '!seen[$0]++')
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _resume_claude "$@"
fi
