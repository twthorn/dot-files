#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Dot Files Setup ==="
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

# Set default shell to bash if not already
CURRENT_SHELL=$(dscl . -read ~/ UserShell 2>/dev/null | awk '{print $2}' || echo "$SHELL")
if [[ "$CURRENT_SHELL" != "/bin/bash" ]]; then
    echo "Current default shell is $CURRENT_SHELL"
    echo "Changing default shell to /bin/bash..."
    chsh -s /bin/bash
    echo "Default shell changed. Open a new terminal for it to take effect."
    echo
else
    echo "Default shell is already bash."
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
        echo "iTerm2 profile installed. Restart iTerm2 to load it."
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
