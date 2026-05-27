#!/bin/bash
# Syncs ~/.bashrc_private to all remote hosts defined in REMOTE_HOSTS.
# Usage: sync_private.sh

set -e

[[ -f "$HOME/.bashrc_private" ]] && source "$HOME/.bashrc_private"

if [[ ${#REMOTE_HOSTS[@]} -eq 0 ]]; then
    echo "No REMOTE_HOSTS defined in ~/.bashrc_private"
    exit 1
fi

for host in "${REMOTE_HOSTS[@]}"; do
    echo "Syncing ~/.bashrc_private -> $host"
    scp "$HOME/.bashrc_private" "$host:~/.bashrc_private"
done

echo "Done."
