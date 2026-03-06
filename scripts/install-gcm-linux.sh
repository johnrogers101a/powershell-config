#!/usr/bin/env bash
# Installs Git Credential Manager on Linux (no root required).
# Downloads the tarball from GitHub Releases, extracts to ~/.local/bin, and configures.
set -e

ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  ARCH_SLUG="amd64" ;;
  aarch64) ARCH_SLUG="arm64" ;;
  *)       echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

INSTALL_DIR="$HOME/.local/bin"
mkdir -p "$INSTALL_DIR"

echo "Fetching latest GCM release..."
LATEST_URL=$(curl -fsSL "https://api.github.com/repos/git-ecosystem/git-credential-manager/releases/latest" \
  | grep -o "\"browser_download_url\": \"[^\"]*gcm-linux_${ARCH_SLUG}\.[0-9.]*\.tar\.gz\"" \
  | grep -o 'https://[^"]*' | head -1)

if [ -z "$LATEST_URL" ]; then
  # Fallback to a known-good release
  LATEST_URL="https://github.com/git-ecosystem/git-credential-manager/releases/latest/download/gcm-linux_${ARCH_SLUG}.tar.gz"
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
