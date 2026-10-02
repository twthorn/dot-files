#!/bin/bash

# Tests _configure_delta in setup.sh: with delta installed, git uses it as the
# pager and diff filter in --color-only mode (classic git diff layout, syntax
# highlighted), and settings for delta's decorated view are removed; without it, no pager is set (so git diff never fails on
# a missing binary). The merge conflict style is zdiff3 only on git >= 2.35,
# which introduced it, and diff3 on older git. Writes to a throwaway global
# git config only.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
export GIT_CONFIG_GLOBAL="$TEST_DIR/gitconfig"
REAL_GIT="$(command -v git)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/../setup.sh"

FAIL=0
check() { # desc expected actual
    if [[ "$2" == "$3" ]]; then
        echo "  ok: $1"
    else
        echo "  FAIL: $1 (expected '$2', got '$3')"
        FAIL=1
    fi
}
global() { "$REAL_GIT" config --global --get "$1"; }

check "git 2.34 gets diff3"   "diff3"  "$(_merge_conflict_style "git version 2.34.1")"
check "git 2.35 gets zdiff3"  "zdiff3" "$(_merge_conflict_style "git version 2.35.0")"
check "git 3.0 gets zdiff3"   "zdiff3" "$(_merge_conflict_style "git version 3.0.0")"
check "apple git gets zdiff3" "zdiff3" "$(_merge_conflict_style "git version 2.39.5 (Apple Git-154)")"

mkdir -p "$TEST_DIR/no-delta" "$TEST_DIR/with-delta"
ln -s "$REAL_GIT" "$TEST_DIR/no-delta/git"
ln -s "$REAL_GIT" "$TEST_DIR/with-delta/git"
printf '#!/bin/sh\ncat\n' > "$TEST_DIR/with-delta/delta"
chmod +x "$TEST_DIR/with-delta/delta"

PATH="$TEST_DIR/no-delta" _configure_delta >/dev/null
check "no delta: pager left unset"        "" "$(global core.pager)"
check "no delta: diff filter left unset"  "" "$(global interactive.diffFilter)"

for key in delta.side-by-side delta.navigate delta.file-style delta.file-decoration-style; do
    "$REAL_GIT" config --global "$key" true
done
PATH="$TEST_DIR/with-delta" _configure_delta >/dev/null
check "delta: classic layout pager"   "delta --color-only" "$(global core.pager)"
check "delta: interactive filter"    "delta --color-only" "$(global interactive.diffFilter)"
check "delta: decorated-view settings removed" "" "$("$REAL_GIT" config --global --get-regexp '^delta\.')"
check "conflict style matches git"   "$(_merge_conflict_style "$("$REAL_GIT" --version)")" "$(global merge.conflictStyle)"

if [[ "$FAIL" -eq 0 ]]; then
    echo "ALL PASS"
else
    echo "FAILURES"
    exit 1
fi
