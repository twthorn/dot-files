#!/bin/bash

# Resolve git identity entirely through conditional includes so every repo picks
# the right email by path -- personal by default, work for repos under any
# WORK_GIT_DIRS entry -- and repair drift wherever it hides:
#   - a top-level user.email in ~/.gitconfig silently shadows the includeIf
#     (git is last-value-wins), so it must never exist; email comes only from
#     the include files.
#   - a repo's local user.name/email overrides the global includes, so a stale
#     value keeps committing from the wrong identity until it is cleared.
# GIT_REPO_ROOT is overridable so tests can point at a throwaway tree.
# Note: a WORK_GIT_DIRS entry must not contain a '.' -- `git config` parses the
# last dot of the key as the value name, which would split a dotted path.
#
# Reads GIT_EMAIL / WORK_EMAIL / GIT_NAME / WORK_GIT_DIRS from the environment
# (setup.sh and this script's own main block source them from ~/.bashrc_private).
#
# Usage (run directly):
#   fix_git_identity.sh              apply the fix
#   fix_git_identity.sh --dry-run    report every mismatch/change without writing
# When sourced (by setup.sh or the tests) only the function is defined.
_fix_git_identity() {
    local dry_run=0
    [[ "${1:-}" == "--dry-run" ]] && dry_run=1

    local repo_root="${GIT_REPO_ROOT:-$HOME/git}"
    local pfx=""
    [[ "$dry_run" == 1 ]] && pfx="would "
    local changes=0

    if [[ -n "$GIT_EMAIL" ]]; then
        local want_personal
        want_personal="$(printf '[user]\n\temail = %s\n' "$GIT_EMAIL")"
        if [[ "$(cat "$HOME/.gitconfig-personal" 2>/dev/null)" != "$want_personal" ]]; then
            changes=$(( changes + 1 ))
            echo "  ${pfx}write ~/.gitconfig-personal (email = $GIT_EMAIL)"
            [[ "$dry_run" == 0 ]] && printf '[user]\n\temail = %s\n' "$GIT_EMAIL" > "$HOME/.gitconfig-personal"
        fi
    fi
    if [[ -n "$WORK_EMAIL" ]]; then
        local want_work
        want_work="$(printf '[user]\n\temail = %s\n' "$WORK_EMAIL")"
        if [[ "$(cat "$HOME/.gitconfig-work" 2>/dev/null)" != "$want_work" ]]; then
            changes=$(( changes + 1 ))
            echo "  ${pfx}write ~/.gitconfig-work (email = $WORK_EMAIL)"
            [[ "$dry_run" == 0 ]] && printf '[user]\n\temail = %s\n' "$WORK_EMAIL" > "$HOME/.gitconfig-work"
        fi
    fi
    if [[ -n "$GIT_NAME" ]] && [[ "$(git config --global --get user.name 2>/dev/null)" != "$GIT_NAME" ]]; then
        changes=$(( changes + 1 ))
        echo "  ${pfx}set global user.name = $GIT_NAME"
        [[ "$dry_run" == 0 ]] && git config --global user.name "$GIT_NAME"
    fi

    # Personal email is the default for every repo, via a plain include.
    if ! git config --global --get-all include.path 2>/dev/null | grep -qxF '~/.gitconfig-personal'; then
        changes=$(( changes + 1 ))
        echo "  ${pfx}add include.path ~/.gitconfig-personal"
        [[ "$dry_run" == 0 ]] && git config --global --add include.path '~/.gitconfig-personal'
    fi

    # Work email overrides personal under each WORK_GIT_DIRS entry. Added after
    # the base include, so for a work repo the includeIf wins (last value).
    if [[ -n "${WORK_GIT_DIRS+x}" ]]; then
        local dir key
        for dir in "${WORK_GIT_DIRS[@]}"; do
            [[ -z "$dir" ]] && continue
            key="includeIf.gitdir:${dir}.path"
            if ! git config --global --get "$key" >/dev/null 2>&1; then
                changes=$(( changes + 1 ))
                echo "  ${pfx}add includeIf gitdir:${dir} -> ~/.gitconfig-work"
                [[ "$dry_run" == 0 ]] && git config --global "$key" '~/.gitconfig-work'
            fi
        done
    fi

    # Drop any global override so identity email comes only from the includes.
    local shadow
    shadow="$(git config --global --get user.email 2>/dev/null)"
    if [[ -n "$shadow" ]]; then
        changes=$(( changes + 1 ))
        echo "  ${pfx}remove global user.email shadow ($shadow)"
        if [[ "$dry_run" == 0 ]]; then
            git config --global --unset-all user.email 2>/dev/null || true
        fi
    fi

    # Strip stale local identity from every repo under repo_root so they all
    # resolve by path through the global includes.
    local stripped=0 gitpath repo cur_email cur_name
    while IFS= read -r gitpath; do
        repo="${gitpath%/.git}"
        if git -C "$repo" config --local --get-regexp '^user\.(email|name)$' >/dev/null 2>&1; then
            cur_email="$(git -C "$repo" config --local --get user.email 2>/dev/null)"
            cur_name="$(git -C "$repo" config --local --get user.name 2>/dev/null)"
            changes=$(( changes + 1 ))
            stripped=$(( stripped + 1 ))
            echo "  ${pfx}clear local identity in ${repo#"$HOME"/} (email=${cur_email:-<none>} name=${cur_name:-<none>})"
            if [[ "$dry_run" == 0 ]]; then
                git -C "$repo" config --local --unset-all user.email 2>/dev/null || true
                git -C "$repo" config --local --unset-all user.name 2>/dev/null || true
            fi
        fi
    done < <(find "$repo_root" -maxdepth 3 -name .git 2>/dev/null)

    if [[ "$dry_run" == 1 ]]; then
        if [[ "$changes" -eq 0 ]]; then
            echo "  dry-run: no changes needed -- git identity already correct"
        else
            echo "  dry-run: $changes change(s) needed ($stripped repo(s) with stale local identity); re-run without --dry-run to apply"
        fi
    else
        echo "  git identity: personal default, work override via includeIf, global shadow removed, $stripped repo(s) repaired"
    fi
}

# When run directly, load private config (for GIT_EMAIL etc.) then apply or preview.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    [[ -f "$HOME/.bashrc_private" ]] && source "$HOME/.bashrc_private"
    _fix_git_identity "${1:-}"
fi
