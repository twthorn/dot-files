#!/bin/bash

# Tests _render_claude_md in setup.sh: %%REVIEWERS%% and the Jira placeholders are
# replaced with values from the private config; unset vars collapse to empty so no
# %% marker is ever left behind in the deployed CLAUDE.md.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP="$SCRIPT_DIR/../setup.sh"

FAIL=0
check_contains() { # desc haystack needle
    if [[ "$2" == *"$3"* ]]; then
        echo "  ok: $1"
    else
        echo "  FAIL: $1 (missing '$3')"
        FAIL=1
    fi
}
check_absent() { # desc haystack needle
    if [[ "$2" != *"$3"* ]]; then
        echo "  ok: $1"
    else
        echo "  FAIL: $1 (found '$3')"
        FAIL=1
    fi
}

# shellcheck disable=SC1090
source "$SETUP"

TMP="$(mktemp)"
cat > "$TMP" <<'EOF'
- Default reviewers: %%REVIEWERS%%
- Create tickets in %%JIRA_PROJECT%% assigned to %%JIRA_ASSIGNEE%% on board %%JIRA_BOARD%%.
EOF

GITHUB_REVIEWERS="alice bob"
JIRA_PROJECT="STREAM"
JIRA_ASSIGNEE="tthornton"
JIRA_BOARD="STREAM"
OUT="$(_render_claude_md "$TMP")"
check_contains "reviewers substituted"    "$OUT" "Default reviewers: alice bob"
check_contains "project substituted"      "$OUT" "in STREAM"
check_contains "assignee substituted"     "$OUT" "assigned to tthornton"
check_contains "board substituted"        "$OUT" "board STREAM."
check_absent   "no leftover placeholder"  "$OUT" "%%"
ERR="$(_render_claude_md "$TMP" 2>&1 >/dev/null)"
if [[ -z "$ERR" ]]; then echo "  ok: render writes no errors"; else echo "  FAIL: render stderr: $ERR"; FAIL=1; fi

unset GITHUB_REVIEWERS JIRA_PROJECT JIRA_ASSIGNEE JIRA_BOARD
OUT="$(_render_claude_md "$TMP")"
check_absent "unset vars leave no placeholder" "$OUT" "%%"

rm -f "$TMP"

if [[ "$FAIL" -eq 0 ]]; then
    echo "ALL PASS"
else
    echo "FAILURES"
    exit 1
fi
