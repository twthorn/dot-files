#!/bin/bash

# Purge stale tmux sessions.
# Kills whole sessions atomically (kill-session takes every pane with it, so a
# stale pane inside an otherwise-active session is never orphaned). The
# currently attached session is always protected.
#
# A session is purged when it is unattached AND either:
#   - idle:  no activity for longer than the threshold (default 14 days), or
#   - blank: every pane is a bare shell whose scrollback contains nothing but
#            noise -- the shell prompt, the `exec bash ... tmux_shell.sh` reload
#            command that setup.sh sends, the pyenv lock error that reload can
#            emit, and ^C. This catches sessions that tmux-continuum restored
#            after a reboot (which bumps their activity clock to "now" so the
#            idle test misses them) but that were never actually used.
#
# If any pane runs a real program (vim, claude, ...) the session counts as used.
#
# Note: #{session_activity} bumps on ANY activity -- background output, and the
# send-keys from setup.sh's reload loop -- so run this BEFORE a setup pass, not
# after, if you want the idle clock to reflect your last real keystroke.
#
# Usage:
#   purge_tmux.sh              # dry-run preview, then prompt before killing
#   purge_tmux.sh --dry-run    # preview only, never kills
#   purge_tmux.sh --force      # kill without prompting
#   purge_tmux.sh --days N     # idle threshold in days (default 14)
#   purge_tmux.sh --blank-only # ignore age; purge only blank sessions
#   purge_tmux.sh --idle-only  # ignore blank check; purge only idle sessions
#
# Flags combine, e.g.: purge_tmux.sh --days 7 --force

# Overridable so tests can point at a throwaway server: TMUX_CMD="tmux -L test"
TMUX_CMD="${TMUX_CMD:-tmux}"

RELOAD_MARKER='exec bash --norc --noprofile'

# Reads a pane's full scrollback on stdin and exits 0 if it shows real
# (user-originated) activity, 1 if it contains only reload/prompt noise.
_scrollback_has_real_activity() {
    awk -v user="$USER" -v reload="$RELOAD_MARKER" '
        {
            line = $0
            sub(/[ \t]+$/, "", line)                       # strip trailing ws
            if (line == "") next                           # blank
            if (line ~ ("^" user " at ")) next             # prompt header line
            if (index(line, reload)) next                  # reload cmd (echo or prompt)
            if (line ~ /pyenv: cannot rehash/) next        # reload byproduct
            if (line ~ /pyenv-rehash: line/) next          # reload byproduct
            if (line ~ /cannot overwrite existing file/) next
            if (line ~ /^\$[ \t]*$/) next                  # bare prompt "$"
            if (line ~ /^\$[ \t]*\^C$/) next               # prompt then ctrl-c
            if (line ~ /^\^C$/) next                        # ctrl-c
            found = 1
            exit
        }
        END { exit(found ? 0 : 1) }
    '
}

# Exits 0 if every pane in the session is a bare shell with only-noise
# scrollback (i.e. the session was never really used), 1 otherwise.
_session_is_blank() {
    local sess="$1" pid cmd
    while IFS=$'\t' read -r pid cmd; do
        case "$cmd" in
            bash|-bash|sh|-sh|zsh|-zsh) ;;      # a shell: inspect its scrollback
            *) return 1 ;;                       # a real program is running
        esac
        if $TMUX_CMD capture-pane -t "$pid" -p -S - 2>/dev/null \
            | _scrollback_has_real_activity; then
            return 1
        fi
    done < <($TMUX_CMD list-panes -s -t "$sess" -F $'#{pane_id}\t#{pane_current_command}' 2>/dev/null)
    return 0
}

_main() {
    local DAYS=14 MODE="prompt" SELECT="both"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)    MODE="dry-run" ;;
            --force)      MODE="force" ;;
            --days)       DAYS="$2"; shift ;;
            --blank-only) SELECT="blank" ;;
            --idle-only)  SELECT="idle" ;;
            *) echo "Unknown option: $1"; return 1 ;;
        esac
        shift
    done

    if ! $TMUX_CMD list-sessions &>/dev/null; then
        echo "No tmux server running."
        return 0
    fi

    local now threshold
    now=$(date +%s)
    threshold=$(( DAYS * 86400 ))

    # Build selection: name<TAB>age_days<TAB>reason, skipping attached sessions.
    # kept accumulates the survivors with the reason they were spared.
    local selected="" kept="" total=0
    while IFS='|' read -r activity attached name; do
        total=$(( total + 1 ))

        local age_days=$(( (now - activity) / 86400 ))

        if [[ "$attached" != "0" ]]; then
            kept+="${name}"$'\t'"${age_days}"$'\t'"attached"$'\n'
            continue
        fi

        local is_idle=false is_blank=false
        (( now - activity > threshold )) && is_idle=true
        if [[ "$SELECT" != "idle" ]] && _session_is_blank "$name"; then
            is_blank=true
        fi

        local reason=""
        case "$SELECT" in
            idle)  [[ "$is_idle" == true ]] && reason="idle" ;;
            blank) [[ "$is_blank" == true ]] && reason="blank" ;;
            both)
                if [[ "$is_idle" == true && "$is_blank" == true ]]; then reason="idle+blank"
                elif [[ "$is_idle" == true ]]; then reason="idle"
                elif [[ "$is_blank" == true ]]; then reason="blank"
                fi ;;
        esac

        if [[ -n "$reason" ]]; then
            selected+="${name}"$'\t'"${age_days}"$'\t'"${reason}"$'\n'
        else
            kept+="${name}"$'\t'"${age_days}"$'\t'"active"$'\n'
        fi
    done < <($TMUX_CMD list-sessions -F '#{session_activity}|#{session_attached}|#{session_name}')

    selected=$(printf '%s' "$selected" | grep -c . >/dev/null && printf '%s' "$selected" | sort -t$'\t' -k1,1)
    kept=$(printf '%s' "$kept" | grep -c . >/dev/null && printf '%s' "$kept" | sort -t$'\t' -k1,1)
    local count kept_count
    count=$(printf '%s' "$selected" | grep -c .)
    kept_count=$(printf '%s' "$kept" | grep -c .)

    echo "Total sessions: $total"
    case "$SELECT" in
        idle)  echo "Criteria:       unattached AND idle > ${DAYS}d" ;;
        blank) echo "Criteria:       unattached AND blank (never used)" ;;
        both)  echo "Criteria:       unattached AND (idle > ${DAYS}d OR blank)" ;;
    esac
    echo "Matched:        $count"
    echo

    _print_list() {
        local title="$1" data="$2"
        printf '%s\n' "$data" | awk -F'\t' 'NF>=3 {printf "  %4dd idle  [%-10s]  %s\n", $2, $3, $1}'
    }

    # The preview (killed + kept + note) is identical for every mode; only the
    # action afterward differs.
    if [[ "$count" -gt 0 ]]; then
        echo "Sessions that would be killed ($count):"
        _print_list "killed" "$selected"
        echo
        if printf '%s' "$selected" | grep -q 'blank'; then
            echo "NOTE: 'blank' means every pane held only a shell prompt + the reload"
            echo "      command. setup.sh's reload wipes scrollback, so if you just ran"
            echo "      setup.sh, used sessions look blank too. Run before setup, or after"
            echo "      a reboot+restore, for blank-detection to be trustworthy."
            echo
        fi
    fi
    if [[ "$kept_count" -gt 0 ]]; then
        echo "Sessions that would be kept ($kept_count):"
        _print_list "kept" "$kept"
        echo
    fi

    if [[ "$count" -eq 0 ]]; then
        echo "Nothing to purge."
        return 0
    fi

    _purge() {
        local killed=0 name age reason
        while IFS=$'\t' read -r name age reason; do
            [[ -z "$name" ]] && continue
            if $TMUX_CMD kill-session -t "=$name" 2>/dev/null; then
                echo "  killed: $name (${age}d, ${reason})"
                killed=$(( killed + 1 ))
            else
                echo "  failed: $name"
            fi
        done <<< "$selected"
        echo
        echo "Purged $killed session(s)."
    }

    case "$MODE" in
        dry-run)
            echo "[dry-run] No sessions killed. Re-run with --force to purge."
            ;;
        force)
            _purge
            ;;
        prompt)
            local reply
            read -r -p "Kill these $count session(s)? [y/N] " reply
            if [[ "$reply" == "y" || "$reply" == "Y" ]]; then
                _purge
            else
                echo "Aborted. No sessions killed."
            fi
            ;;
    esac
}

# Only run when executed directly, so tests can source the functions above.
# The explicit exit stops bash reading further bytes from this file, so an
# in-place overwrite (e.g. setup.sh redeploying) can't make a running instance
# resume at a shifted offset.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _main "$@"
    exit $?
fi
