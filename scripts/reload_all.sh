#!/bin/bash

# Script to reload .bashrc in all tmux panes and .tmux.conf in all sessions

echo "=== Reloading tmux configuration and bash environments ==="
echo

# Check if tmux is running
if ! tmux list-sessions &>/dev/null; then
    echo "No tmux sessions found."
    exit 0
fi

# Reload .tmux.conf in all sessions
echo "Reloading .tmux.conf in all sessions..."
for session in $(tmux list-sessions -F '#{session_name}'); do
    tmux source-file ~/.tmux.conf -t "$session" 2>/dev/null && echo "  ✓ Session: $session"
done
echo

# Reload .bashrc in all bash panes
echo "Reloading .bashrc in all bash panes..."
tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{pane_current_command}' | while read pane cmd; do
    if [[ "$cmd" == "bash" ]] || [[ "$cmd" == "-bash" ]]; then
        # Send source command to the pane
        tmux send-keys -t "$pane" "source ~/.bashrc" C-m
        echo "  ✓ Pane: $pane ($cmd)"
    fi
done
echo

echo "Reload complete!"
echo
echo "Note: Only bash panes were reloaded. Panes running other processes were skipped."
