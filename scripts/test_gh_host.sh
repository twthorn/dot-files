#!/bin/bash

# Tests .bash_gh: gh commands run inside a repo target the host of its origin
# remote (github.com vs an enterprise host), so `gh search` / `gh api` hit the right
# instance; an explicit GH_HOST and non-GitHub or remote-less dirs are left alone.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

# shellcheck disable=SC1091
source "$SCRIPT_DIR/../.bash_gh"
ENTERPRISE_NAME="acme"

FAIL=0
check() { # desc expected actual
    if [[ "$2" == "$3" ]]; then
        echo "  ok: $1"
    else
        echo "  FAIL: $1 (expected '$2', got '$3')"
        FAIL=1
    fi
}

check "ssh github.com remote"        "github.com"       "$(_gh_remote_host git@github.com:twthorn/vitess.git)"
check "ssh enterprise remote"        "acme-github.com" "$(_gh_remote_host git@acme-github.com:corp/viz.git)"
check "https remote"                 "github.com"       "$(_gh_remote_host https://github.com/grpc/grpc-go.git)"
check "https remote with token"      "acme-github.com" "$(_gh_remote_host https://tok@acme-github.com/corp/x.git)"
check "non-GitHub remote ignored"    ""                 "$(_gh_remote_host git@gitlab.com:a/b.git)"
check "other enterprise host ignored" ""                "$(_gh_remote_host git@other-github.com:a/b.git)"

# Replace the real binary with one that reports the host it was given.
mkdir -p "$TEST_DIR/bin"
printf '#!/bin/bash\necho "${GH_HOST:-default}"\n' > "$TEST_DIR/bin/gh"
chmod +x "$TEST_DIR/bin/gh"
PATH="$TEST_DIR/bin:$PATH"

git init -q "$TEST_DIR/public" && git -C "$TEST_DIR/public" remote add origin git@github.com:twthorn/vitess.git
git init -q "$TEST_DIR/corp"   && git -C "$TEST_DIR/corp"   remote add origin git@acme-github.com:corp/viz.git
mkdir -p "$TEST_DIR/plain"

check "gh in public repo uses github.com"      "github.com"       "$(cd "$TEST_DIR/public" && gh search code x)"
check "gh in corp repo uses acme-github.com"  "acme-github.com" "$(cd "$TEST_DIR/corp" && gh search code x)"
check "gh outside a repo uses default host"    "default"          "$(cd "$TEST_DIR/plain" && gh search code x)"
check "explicit GH_HOST wins"                  "acme-github.com" "$(cd "$TEST_DIR/public" && GH_HOST=acme-github.com gh search code x)"

if [[ "$FAIL" -eq 0 ]]; then
    echo "ALL PASS"
else
    echo "FAILURES"
    exit 1
fi
