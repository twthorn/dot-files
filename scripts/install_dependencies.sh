#!/bin/bash

set -e

echo "=== Installing Dependencies ==="
echo

# Core packages (Homebrew names — Linux names mapped below where they differ)
COMMON_PACKAGES="bash tmux git gh tig vim maven"

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
    # Map package names to the binary they provide for "already installed" checks
    # Format: "package_name:binary_name"
    LINUX_PACKAGES="bash:bash tmux:tmux git:git gh:gh tig:tig vim:vim maven:mvn universal-ctags:ctags mysql-server:mysql"

    # Detect package manager
    if command -v apt-get &>/dev/null; then
        PKG_MGR="apt"
    elif command -v dnf &>/dev/null; then
        PKG_MGR="dnf"
    elif command -v yum &>/dev/null; then
        PKG_MGR="yum"
    elif command -v pacman &>/dev/null; then
        PKG_MGR="pacman"
    else
        PKG_MGR=""
    fi

    if [[ -z "$PKG_MGR" ]]; then
        echo "Warning: Could not detect package manager. Please install manually."
    else
        echo "Installing packages via $PKG_MGR..."
        [[ "$PKG_MGR" == "apt" ]] && sudo apt-get update

        for entry in $LINUX_PACKAGES; do
            pkg="${entry%%:*}"
            bin="${entry##*:}"
            if command -v "$bin" &>/dev/null; then
                echo "  $pkg: already installed ($bin found)"
            else
                echo "  $pkg: installing..."
                case "$PKG_MGR" in
                    apt)    sudo apt-get install -y "$pkg" ;;
                    dnf)    sudo dnf install -y "$pkg" ;;
                    yum)    sudo yum install -y "$pkg" ;;
                    pacman) sudo pacman -S --noconfirm "$pkg" ;;
                esac
            fi
        done
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
