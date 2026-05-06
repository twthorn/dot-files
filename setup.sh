#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Dot Files Setup ==="
echo

# Install dependencies first
echo "Installing dependencies..."
"$SCRIPT_DIR/scripts/install_dependencies.sh"
echo

# Copy dot files to home directory
echo "Copying dot files to $HOME..."
for f in $(ls -A | egrep '^\.' | grep -v .gitconfig | grep -v ".git$" | grep -v .gitignore)
do
    echo "  cp -r $f $HOME"
    cp -r "$f" "$HOME"
done
echo

# Copy helper scripts to ~/.local/bin
if [[ ! -d "$HOME/.local/bin" ]]; then
    mkdir -p "$HOME/.local/bin" 2>/dev/null || sudo mkdir -p "$HOME/.local/bin" && sudo chown -R "$USER" "$HOME/.local"
fi
cp "$SCRIPT_DIR/scripts/restore_tmux.sh" "$HOME/.local/bin/"
cp "$SCRIPT_DIR/scripts/tmux_shell.sh" "$HOME/.local/bin/"

# Install tmux plugins via TPM (must run after dot files are copied so ~/.tmux.conf is current)
TPM_DIR="$HOME/.tmux/plugins/tpm"
mkdir -p "$HOME/.tmux/resurrect"
if [[ -x "$TPM_DIR/bin/install_plugins" ]]; then
    # Reload tmux config so the running server picks up TMUX_PLUGIN_MANAGER_PATH
    if tmux list-sessions &>/dev/null; then
        tmux source-file ~/.tmux.conf 2>/dev/null
    fi
    echo "Installing tmux plugins..."
    "$TPM_DIR/bin/install_plugins"
    # Reload again so tmux loads the newly installed plugins
    if tmux list-sessions &>/dev/null; then
        tmux source-file ~/.tmux.conf 2>/dev/null
    fi
    echo
fi

# Set up git config
echo "Setting up git configs..."
git config --global init.templatedir '~/.git_template'
git config --global alias.ctags '!.git/hooks/ctags'
echo

# Set default shell to bash
if [[ "$(uname)" == "Darwin" ]]; then
    PREFERRED_BASH="/opt/homebrew/bin/bash"
    CURRENT_SHELL=$(dscl . -read ~/ UserShell 2>/dev/null | awk '{print $2}' || echo "$SHELL")
else
    PREFERRED_BASH="/bin/bash"
    CURRENT_SHELL="$(getent passwd "$USER" 2>/dev/null | cut -d: -f7 || echo "$SHELL")"
fi
if [[ -x "$PREFERRED_BASH" ]] && [[ "$CURRENT_SHELL" != "$PREFERRED_BASH" ]]; then
    echo "Current default shell is $CURRENT_SHELL"
    echo "Changing default shell to $PREFERRED_BASH (modern bash)..."
    chsh -s "$PREFERRED_BASH"
    echo "Default shell changed. Open a new terminal for it to take effect."
    echo
elif [[ "$CURRENT_SHELL" == "$PREFERRED_BASH" ]]; then
    echo "Default shell is already modern bash ($PREFERRED_BASH)."
    echo
elif [[ "$CURRENT_SHELL" == *"bash"* ]]; then
    echo "Default shell is bash ($CURRENT_SHELL)."
    echo
else
    echo "Current default shell is $CURRENT_SHELL"
    echo "Changing default shell to bash..."
    chsh -s /bin/bash
    echo "Default shell changed. Open a new terminal for it to take effect."
    echo
fi

# Check and apply keyboard repeat settings (macOS only)
if [[ "$(uname)" == "Darwin" ]]; then
    NEEDS_RESTART=false

    CURRENT_INITIAL=$(defaults read -g InitialKeyRepeat 2>/dev/null || echo "not set")
    CURRENT_REPEAT=$(defaults read -g KeyRepeat 2>/dev/null || echo "not set")

    DESIRED_INITIAL=10
    DESIRED_REPEAT=1

    if [[ "$CURRENT_INITIAL" != "$DESIRED_INITIAL" ]] || [[ "$CURRENT_REPEAT" != "$DESIRED_REPEAT" ]]; then
        echo "Configuring keyboard repeat settings..."
        echo "  Current InitialKeyRepeat: $CURRENT_INITIAL (desired: $DESIRED_INITIAL)"
        echo "  Current KeyRepeat: $CURRENT_REPEAT (desired: $DESIRED_REPEAT)"

        defaults write -g InitialKeyRepeat -int $DESIRED_INITIAL
        defaults write -g KeyRepeat -int $DESIRED_REPEAT

        NEEDS_RESTART=true
        echo
    else
        echo "Keyboard repeat settings already configured."
        echo
    fi

    # Install iTerm2 dynamic profile (macOS only)
    ITERM_DYNAMIC_PROFILES="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
    if [[ -f "$SCRIPT_DIR/iterm_profile.json" ]]; then
        mkdir -p "$ITERM_DYNAMIC_PROFILES"
        cp "$SCRIPT_DIR/iterm_profile.json" "$ITERM_DYNAMIC_PROFILES/"
        echo "iTerm2 profile installed. Restart iTerm2 and set 'DotFiles Dark' as default in Settings → Profiles."
        echo
    fi

    # Disable iTerm2 SSH shell integration (causes escape sequence leaks on remote hosts)
    defaults write com.googlecode.iterm2 sshIntegrationLevel -int 0
    echo "iTerm2 SSH shell integration disabled."
    echo

    if [[ "$NEEDS_RESTART" == "true" ]]; then
        echo "=============================================="
        echo "  RESTART REQUIRED"
        echo "  Keyboard settings have been changed."
        echo "  Please restart your computer for changes"
        echo "  to take effect."
        echo "=============================================="
        echo
    fi
fi

echo "Setup complete!"
echo

# Disable set -e for tmux operations (rename can fail for valid reasons)
set +e

# Reload .bashrc in all running tmux bash panes and fix session names
if tmux list-sessions &>/dev/null; then
    echo "Fixing tmux session names..."
    while IFS= read -r line; do
        sid="${line%% *}"
        session="${line#* }"

        # Already correctly named (starts with ~/ or /)
        if [[ "$session" == "~/"* ]] || [[ "$session" == /* ]]; then
            # Fix double-tilde from previous bug
            if [[ "$session" == "~/~/"* ]]; then
                fixed="${session#"~/"}"
                if tmux rename-session -t "$sid" "$fixed" 2>/dev/null; then
                    echo "  fixed: $session -> $fixed"
                else
                    echo "  failed: $session -> $fixed"
                fi
            else
                echo "  ok: $session"
            fi
            continue
        fi

        # Try pane's current working directory first
        pane_path=$(tmux list-panes -t "$sid" -F '#{pane_current_path}' 2>/dev/null | head -1)
        expected=$(echo "$pane_path" | sed "s|^$HOME/|~/|")

        # If pane is at $HOME, fall back to prepending ~/ to the session name
        if [[ "$pane_path" == "$HOME" ]] || [[ -z "$pane_path" ]]; then
            expected="~/$session"
        fi

        if [[ "$expected" == "$session" ]]; then
            echo "  ok: $session"
        elif tmux has-session -t "=$expected" 2>/dev/null; then
            echo "  skipped: $session (session '$expected' already exists)"
        else
            if tmux rename-session -t "$sid" "$expected" 2>/dev/null; then
                echo "  renamed: $session -> $expected"
            else
                echo "  failed: $session -> $expected"
            fi
        fi
    done < <(tmux list-sessions -F '#{session_id} #{session_name}')
    echo

    echo "Reloading .bashrc in all tmux bash panes..."
    current_pane=$(tmux display-message -p '#{session_id}:#{window_index}.#{pane_index}' 2>/dev/null)
    while IFS= read -r line; do
        pane="${line%% *}"
        cmd="${line#* }"
        if [[ "$pane" == "$current_pane" ]]; then
            continue
        fi
        if [[ "$cmd" == "bash" ]] || [[ "$cmd" == "-bash" ]]; then
            tmux copy-mode -q -t "$pane" 2>/dev/null
            tmux send-keys -t "$pane" "exec bash --norc --noprofile ~/.local/bin/tmux_shell.sh" C-m 2>/dev/null
            echo "  reloaded: $pane"
        fi
    done < <(tmux list-panes -a -F '#{session_id}:#{window_index}.#{pane_index} #{pane_current_command}')
    echo
fi

set -e

echo "Reloading .bashrc..."
source "$HOME/.bashrc"
echo "Environment updated. Changes are now active in this shell."
