#!/bin/bash

set -e

echo "=== Installing Dependencies ==="
echo

# Core packages common across all OSes
COMMON_PACKAGES="bash tmux git tig vim ctags maven mysql"

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

    # macOS-specific packages (pyenv and goenv for version management)
    MACOS_PACKAGES="$COMMON_PACKAGES pyenv goenv"

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
    # Linux - detect package manager
    if command -v apt-get &>/dev/null; then
        echo "Installing packages via apt..."
        sudo apt-get update
        sudo apt-get install -y $COMMON_PACKAGES
    elif command -v dnf &>/dev/null; then
        echo "Installing packages via dnf..."
        sudo dnf install -y $COMMON_PACKAGES
    elif command -v yum &>/dev/null; then
        echo "Installing packages via yum..."
        sudo yum install -y $COMMON_PACKAGES
    elif command -v pacman &>/dev/null; then
        echo "Installing packages via pacman..."
        sudo pacman -S --noconfirm $COMMON_PACKAGES
    else
        echo "Warning: Could not detect package manager. Please install manually:"
        echo "  $COMMON_PACKAGES"
    fi
    echo
else
    echo "Warning: Unsupported OS '$OS'. Please install dependencies manually."
    echo
fi

echo "Dependencies installation complete!"
