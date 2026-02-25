#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Dot Files Setup ==="
echo

# Install dependencies first
echo "Installing dependencies..."
"$SCRIPT_DIR/install_dependencies.sh"
echo

# Copy dot files to home directory
echo "Copying dot files to $HOME..."
for f in $(ls -A | egrep '^\.' | grep -v .gitconfig | grep -v ".git$" | grep -v .gitignore)
do
    echo "  cp -r $f $HOME"
    cp -r "$f" "$HOME"
done
echo

# Set up git ctags integration
echo "Setting up ctags in git configs..."
git config --global init.templatedir '~/.git_template'
git config --global alias.ctags '!.git/hooks/ctags'
echo

# Set default shell to modern bash (Homebrew) if available
if [[ "$(uname)" == "Darwin" ]]; then
    PREFERRED_BASH="/opt/homebrew/bin/bash"
else
    PREFERRED_BASH="/bin/bash"
fi

CURRENT_SHELL=$(dscl . -read ~/ UserShell 2>/dev/null | awk '{print $2}' || echo "$SHELL")
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
        echo "iTerm2 profile installed."
        # Set it as the default profile
        defaults write com.googlecode.iterm2 "Default Bookmark Guid" -string "dotfiles-dark-profile-001"
        echo "iTerm2 default profile set. Restart iTerm2 to apply."
        echo
    fi

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
