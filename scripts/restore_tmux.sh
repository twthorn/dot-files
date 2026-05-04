#!/bin/bash

# Smart tmux resurrect restore.
# Picks the largest backup if the latest is significantly smaller (degraded).
# Otherwise uses the latest backup.
#
# Usage:
#   restore_tmux.sh          # interactive — shows info, updates 'last', prompts to restore
#   restore_tmux.sh --auto   # silent — for tmux auto-hook, updates 'last' only if degraded
#   restore_tmux.sh --dry-run # preview only

RESURRECT_DIR="$HOME/.tmux/resurrect"
MODE="${1:-interactive}"

[[ ! -d "$RESURRECT_DIR" ]] && { [[ "$MODE" != "--auto" ]] && echo "No resurrect directory found."; exit 0; }

latest=$(ls -t "$RESURRECT_DIR"/tmux_resurrect_*.txt 2>/dev/null | head -1)
largest=$(ls -S "$RESURRECT_DIR"/tmux_resurrect_*.txt 2>/dev/null | head -1)

[[ -z "$latest" ]] && { [[ "$MODE" != "--auto" ]] && echo "No backups found."; exit 0; }
[[ -z "$largest" ]] && exit 0

latest_name=$(basename "$latest")
largest_name=$(basename "$largest")
latest_size=$(wc -c < "$latest" | tr -d ' ')
largest_size=$(wc -c < "$largest" | tr -d ' ')

# Determine if latest is degraded (less than 70% of largest)
degraded=false
if [[ "$largest_size" -gt 0 ]] && [[ "$latest" != "$largest" ]]; then
    threshold=$(( largest_size * 70 / 100 ))
    [[ "$latest_size" -lt "$threshold" ]] && degraded=true
fi

if [[ "$degraded" == "true" ]]; then
    best="$largest_name"
else
    best="$latest_name"
fi

case "$MODE" in
    --auto)
        # Silent mode for tmux hook — only switch if degraded
        if [[ "$degraded" == "true" ]]; then
            cd "$RESURRECT_DIR" && ln -sf "$best" last
        fi
        ;;
    --dry-run)
        echo "Latest:  $latest_name ($latest_size bytes)"
        echo "Largest: $largest_name ($largest_size bytes)"
        echo "Degraded: $degraded"
        echo "[dry-run] Would use: $best"
        echo
        echo "Top 5 backups by size:"
        ls -lS "$RESURRECT_DIR"/tmux_resurrect_*.txt | head -5 | awk '{print "  " $5 " bytes  " $NF}'
        ;;
    *)
        current=$(readlink "$RESURRECT_DIR/last" 2>/dev/null)
        echo "Current:  $current"
        echo "Latest:   $latest_name ($latest_size bytes)"
        echo "Largest:  $largest_name ($largest_size bytes)"
        echo "Degraded: $degraded"
        echo "Selected: $best"
        echo
        echo "Top 5 backups by size:"
        ls -lS "$RESURRECT_DIR"/tmux_resurrect_*.txt | head -5 | awk '{print "  " $5 " bytes  " $NF}'
        echo
        cd "$RESURRECT_DIR" && ln -sf "$best" last
        echo "Updated 'last' -> $best"
        echo "Now restore in tmux: Ctrl-Space, then Ctrl-r"
        ;;
esac
