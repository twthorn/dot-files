#!/bin/bash

# Tests _effective_remote_hosts in setup.sh: REMOTE_HOSTS always deploy; GOV_HOSTS
# deploy only when include_gov is "true" (the --include-gov flag). One host per
# line, no stray blanks when an array is empty or unset.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP="$SCRIPT_DIR/../setup.sh"

FAIL=0
check() { # desc expected actual
    if [[ "$2" == "$3" ]]; then
        echo "  ok: $1"
    else
        echo "  FAIL: $1 (expected '$2', got '$3')"
        FAIL=1
    fi
}
hosts() { _effective_remote_hosts "$1" "${2:-}" | tr '\n' ' ' | sed 's/ *$//'; }

# shellcheck disable=SC1090
source "$SETUP"

REMOTE_HOSTS=("host-a" "host-b")
GOV_HOSTS=("gov-1" "gov-2")
check "default excludes gov"        "host-a host-b"             "$(hosts false)"
check "include-gov appends gov"     "host-a host-b gov-1 gov-2" "$(hosts true)"

unset GOV_HOSTS
check "no gov array is fine"        "host-a host-b"             "$(hosts true)"

REMOTE_HOSTS=()
GOV_HOSTS=("gov-1")
check "gov-only when remote empty"  "gov-1"                     "$(hosts true)"
check "nothing when remote empty, gov excluded" ""              "$(hosts false)"

# --gov-only: GOV_HOSTS exclusively, REMOTE_HOSTS skipped even when populated.
REMOTE_HOSTS=("host-a" "host-b")
GOV_HOSTS=("gov-1" "gov-2")
check "gov-only flag skips remote"  "gov-1 gov-2"               "$(hosts true true)"
unset GOV_HOSTS
check "gov-only with no gov array"  ""                          "$(hosts true true)"

# _is_gov_host: gov hosts use a different (no-github) transport, so membership
# must be detected exactly.
REMOTE_HOSTS=("host-a")
GOV_HOSTS=("gov-1" "gov-2")
if _is_gov_host "gov-1"; then r=yes; else r=no; fi
check "gov member detected"         "yes" "$r"
if _is_gov_host "host-a"; then r=yes; else r=no; fi
check "non-gov host not gov"        "no"  "$r"
unset GOV_HOSTS
if _is_gov_host "anything"; then r=yes; else r=no; fi
check "no gov array -> not gov"     "no"  "$r"

if [[ "$FAIL" -eq 0 ]]; then
    echo "ALL PASS"
else
    echo "FAILURES"
    exit 1
fi
