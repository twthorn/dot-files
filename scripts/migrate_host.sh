#!/bin/bash

# Migrate home directory to a new remote dev host.
# Usage: migrate_host.sh <new-host> [old-host]
#
# If old-host is omitted, copies from the current machine.
# After copying, runs setup.sh on the new host.

set -e

NEW_HOST="$1"
OLD_HOST="${2:-}"

if [[ -z "$NEW_HOST" ]]; then
    echo "Usage: migrate_host.sh <new-host> [old-host]"
    echo
    echo "Examples:"
    echo "  migrate_host.sh new-kube-host              # copy from this machine to new host"
    echo "  migrate_host.sh new-kube-host old-kube-host  # copy between two remote hosts"
    exit 1
fi

echo "=== Dev Host Migration ==="
echo

# Pre-flight: verify SSH access
echo "Checking SSH access to $NEW_HOST..."
if ! ssh -o ConnectTimeout=5 "$NEW_HOST" "echo ok" >/dev/null 2>&1; then
    echo "ERROR: Cannot SSH to $NEW_HOST"
    exit 1
fi
echo "  OK"

if [[ -n "$OLD_HOST" ]]; then
    echo "Checking SSH access to $OLD_HOST..."
    if ! ssh -o ConnectTimeout=5 "$OLD_HOST" "echo ok" >/dev/null 2>&1; then
        echo "ERROR: Cannot SSH to $OLD_HOST"
        exit 1
    fi
    echo "  OK"
fi
echo

# Sync home directory
if [[ -n "$OLD_HOST" ]]; then
    echo "Syncing $OLD_HOST:~/ -> $NEW_HOST:~/..."
    echo "(This may take a while for large repos)"
    echo
    ssh "$OLD_HOST" "rsync -avz --progress ~/ $NEW_HOST:~/"
else
    echo "Syncing ~/ -> $NEW_HOST:~/..."
    echo "(This may take a while for large repos)"
    echo
    rsync -avz --progress ~/ "$NEW_HOST:~/"
fi

echo
echo "Sync complete."
echo

# Run setup on new host
DOTFILES_DIR="git/twthorn/dot-files"
echo "Running setup.sh on $NEW_HOST..."
echo
ssh -t "$NEW_HOST" "cd ~/$DOTFILES_DIR && git pull && ./setup.sh"

echo
echo "=== Migration Complete ==="
echo
echo "Summary:"
echo "  Home directory synced to $NEW_HOST"
echo "  setup.sh ran successfully"
echo
echo "Verify on $NEW_HOST:"
echo "  ssh $NEW_HOST"
echo "  tmux            # start tmux"
echo "  trestore        # restore saved sessions, then prefix + Ctrl-r"
echo "  echo \$TMOUT     # should be empty"
echo "  git config user.email  # check in a work repo"
echo
if ssh "$NEW_HOST" "test -f ~/.bashrc_private"; then
    echo "  ~/.bashrc_private: copied from old host"
else
    echo "  WARNING: ~/.bashrc_private not found — copy .bashrc_private.example and configure it"
fi
