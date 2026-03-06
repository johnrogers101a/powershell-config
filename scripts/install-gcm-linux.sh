#!/usr/bin/env bash
# Installs Git Credential Manager on Linux (no root required).
# Downloads the tarball from GitHub Releases, extracts to ~/.local/bin, and configures.
set -e

ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  ARCH_SLUG="x64" ;;
  aarch64) ARCH_SLUG="arm64" ;;
  *)       echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

INSTALL_DIR="$HOME/.local/bin"
mkdir -p "$INSTALL_DIR"

# Check if already installed
if command -v git-credential-manager &>/dev/null; then
  echo "✓ git-credential-manager is already installed ($(git-credential-manager --version 2>/dev/null || echo 'unknown version'))"
  git-credential-manager configure
  exit 0
fi

echo "Fetching latest GCM release..."
API_RESPONSE=$(curl -fsSL "https://api.github.com/repos/git-ecosystem/git-credential-manager/releases/latest")
LATEST_URL=$(echo "$API_RESPONSE" | python3 -c "
import sys, json
assets = json.load(sys.stdin)['assets']
matches = [a['browser_download_url'] for a in assets
           if 'linux-${ARCH_SLUG}' in a['name'] and a['name'].endswith('.tar.gz')
           and 'symbols' not in a['name']]
print(matches[0] if matches else '')
" 2>/dev/null)

if [ -z "$LATEST_URL" ]; then
  echo "✗ Could not determine GCM download URL from GitHub API"
  exit 1
fi

echo "Downloading GCM from $LATEST_URL ..."
TMP=$(mktemp -d)
curl -fsSL "$LATEST_URL" -o "$TMP/gcm.tar.gz"
tar -xzf "$TMP/gcm.tar.gz" -C "$INSTALL_DIR"
rm -rf "$TMP"

# Ensure ~/.local/bin is in PATH for this session
export PATH="$INSTALL_DIR:$PATH"

echo "Configuring GCM..."
git-credential-manager configure

echo "✓ Git Credential Manager installed and configured"
