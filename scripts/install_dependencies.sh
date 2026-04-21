#!/bin/bash

set -e

echo "=== Installing Dependencies ==="
echo

# Core packages (Homebrew names — Linux names mapped below where they differ)
COMMON_PACKAGES="bash tmux git tig vim maven"

# Detect OS
OS="$(uname)"

if [[ "$OS" == "Darwin" ]]; then
    # macOS - use Homebrew
    if ! command -v brew &>/dev/null; then
        echo "Homebrew not found. Installing..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add Homebrew to PATH for this session
        if [[ -d /opt/homebrew/bin ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -d /usr/local/bin/brew ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
        echo
    fi

    echo "Installing packages via Homebrew..."

    MACOS_PACKAGES="$COMMON_PACKAGES ctags mysql pyenv goenv"

    for pkg in $MACOS_PACKAGES; do
        if brew list "$pkg" &>/dev/null; then
            echo "  $pkg: already installed"
        else
            echo "  $pkg: installing..."
            brew install "$pkg"
        fi
    done
    echo

    # Add Homebrew bash to allowed shells if not already there
    BREW_BASH="/opt/homebrew/bin/bash"
    if [[ -x "$BREW_BASH" ]]; then
        if ! grep -q "$BREW_BASH" /etc/shells; then
            echo "Adding $BREW_BASH to /etc/shells (requires sudo)..."
            echo "$BREW_BASH" | sudo tee -a /etc/shells
            echo
        fi
    fi

elif [[ "$OS" == "Linux" ]]; then
    # Package name mappings for Linux (ctags -> universal-ctags, mysql -> mysql-server)
    LINUX_PACKAGES="$COMMON_PACKAGES universal-ctags mysql-server"

    if command -v apt-get &>/dev/null; then
        echo "Installing packages via apt..."
        sudo apt-get update
        sudo apt-get install -y $LINUX_PACKAGES
    elif command -v dnf &>/dev/null; then
        echo "Installing packages via dnf..."
        sudo dnf install -y $LINUX_PACKAGES
    elif command -v yum &>/dev/null; then
        echo "Installing packages via yum..."
        sudo yum install -y $LINUX_PACKAGES
    elif command -v pacman &>/dev/null; then
        echo "Installing packages via pacman..."
        sudo pacman -S --noconfirm $LINUX_PACKAGES
    else
        echo "Warning: Could not detect package manager. Please install manually:"
        echo "  $LINUX_PACKAGES"
    fi
    echo
else
    echo "Warning: Unsupported OS '$OS'. Please install dependencies manually."
    echo
fi

echo "Dependencies installation complete!"

# Git-based tools
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [[ -d "$TPM_DIR" ]]; then
    echo "  tpm: already installed"
else
    echo "  tpm: installing..."
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
fi
echo
