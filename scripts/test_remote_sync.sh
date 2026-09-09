#!/bin/bash

# Tests _remote_sync_repo_cmd in setup.sh: the snippet that runs on a remote host
# must clone the dot-files repo -- creating the ~/git/<owner> parent -- when it is
# missing, and pull when it already exists. Exercised for real against a local
# repo standing in for origin, in a throwaway HOME -- no mocking.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP="$SCRIPT_DIR/../setup.sh"
export GIT_CONFIG_NOSYSTEM=1

FAIL=0
check() { # desc expected actual
    if [[ "$2" == "$3" ]]; then
        echo "  ok: $1"
    else
        echo "  FAIL: $1 (expected '$2', got '$3')"
        FAIL=1
    fi
}

# shellcheck disable=SC1090
source "$SETUP"

WORK="$(cd "$(mktemp -d)" && pwd -P)"
ORIGIN="$WORK/origin"
export HOME="$WORK/home"
mkdir -p "$HOME"
REPO_DIR="git/twthorn/dot-files"

git init -q -b master "$ORIGIN"
git -C "$ORIGIN" config user.email t@example.com
git -C "$ORIGIN" config user.name  tester
echo one > "$ORIGIN/A"
git -C "$ORIGIN" add A && git -C "$ORIGIN" commit -q -m first

CMD="$(_remote_sync_repo_cmd "$REPO_DIR" "$ORIGIN")"

# Missing -> clone, creating the nested parent dirs.
check "repo absent before"    ""       "$( [[ -e "$HOME/$REPO_DIR" ]] && echo exists )"
bash -c "$CMD" >/dev/null 2>&1
check "cloned repo present"   "exists" "$( [[ -d "$HOME/$REPO_DIR/.git" ]] && echo exists )"
check "clone brought file A"  "one"    "$(cat "$HOME/$REPO_DIR/A" 2>/dev/null)"

# Existing -> pull picks up a new commit.
echo two > "$ORIGIN/B"
git -C "$ORIGIN" add B && git -C "$ORIGIN" commit -q -m second
bash -c "$CMD" >/dev/null 2>&1
check "pull brought file B"   "two"    "$(cat "$HOME/$REPO_DIR/B" 2>/dev/null)"

rm -rf "$WORK"
if [[ "$FAIL" -eq 0 ]]; then
    echo "ALL PASS"
else
    echo "FAILURES"
    exit 1
fi
