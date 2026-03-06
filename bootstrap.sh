#!/usr/bin/env bash
# Bootstrap script for PowerShell profile installation on Linux and macOS.
# Installs PowerShell and Homebrew if missing, then runs install.ps1.
#
# Usage:
#   curl -fsSL https://stprofilewus3.blob.core.windows.net/profile-config/bootstrap.sh | bash
#   curl -fsSL https://stprofilewus3.blob.core.windows.net/profile-config/bootstrap.sh | bash -s -- -Profile John
#   curl -fsSL https://stprofilewus3.blob.core.windows.net/profile-config/bootstrap.sh | bash -s -- -No-Install

set -e

AZURE_BASE_URL="https://stprofilewus3.blob.core.windows.net/profile-config"

echo ""
echo "========================================"
echo "PowerShell Profile Bootstrap"
echo "========================================"
echo ""

# ── 1. PowerShell ────────────────────────────────────────────────────────────
if command -v pwsh &>/dev/null; then
    echo "✓ PowerShell $(pwsh --version) already installed"
else
    echo "PowerShell not found. Installing..."
    curl -fsSL https://aka.ms/install-powershell.sh | bash
    # The install script puts pwsh in ~/.local/bin by default for non-root users
    export PATH="$HOME/.local/bin:$PATH"
    if ! command -v pwsh &>/dev/null; then
        echo "✗ PowerShell installation failed. Please install manually:"
        echo "  curl -fsSL https://aka.ms/install-powershell.sh | bash"
        exit 1
    fi
    echo "✓ PowerShell $(pwsh --version) installed"
fi

# ── 2. Homebrew ───────────────────────────────────────────────────────────────
_setup_brew_env() {
    if [ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    elif [ -f "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -f "/usr/local/bin/brew" ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
}

_setup_brew_env

if command -v brew &>/dev/null; then
    echo "✓ Homebrew $(brew --version | head -1) already installed"
else
    echo "Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    _setup_brew_env
    if ! command -v brew &>/dev/null; then
        echo "✗ Homebrew installation failed. Please install manually: https://brew.sh"
        exit 1
    fi
    echo "✓ Homebrew $(brew --version | head -1) installed"
fi

# ── 3. Download and run install.ps1 ──────────────────────────────────────────
echo ""
echo "Downloading installer..."

CACHE_BUSTER="v=$(date +%s)"
TEMP_SCRIPT=$(mktemp /tmp/install-XXXXXX.ps1)

curl -fsSL "${AZURE_BASE_URL}/install.ps1?${CACHE_BUSTER}" -o "$TEMP_SCRIPT"

echo "Executing installer..."
echo ""

# Pass through any arguments (e.g. -Profile John or -No-Install)
pwsh -NoProfile -ExecutionPolicy Bypass "$TEMP_SCRIPT" "$@"
EXIT_CODE=$?

rm -f "$TEMP_SCRIPT"
exit $EXIT_CODE
