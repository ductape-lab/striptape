#!/bin/bash
set -e

echo "🩹 Installing striptape..."

RELEASE_URL="https://github.com/ductape-lab/striptape/releases/latest/download/striptape.zip"
TMP_DIR=$(mktemp -d)
ZIP_FILE="$TMP_DIR/striptape.zip"

# Download latest release
curl -fL --progress-bar "$RELEASE_URL" -o "$ZIP_FILE"

# Unzip to /Applications
unzip -q -o "$ZIP_FILE" -d "$TMP_DIR"

# Close any running instance
pkill -x striptape 2>/dev/null || true

# Move to Applications
rm -rf /Applications/striptape.app
mv "$TMP_DIR/striptape.app" /Applications/striptape.app

# Strip macOS quarantine attribute (bypasses unnotarized warning)
xattr -cr /Applications/striptape.app 2>/dev/null || true

# Cleanup
rm -rf "$TMP_DIR"

echo "✅ Installed to /Applications/striptape.app"
echo "🚀 Launching striptape..."
open /Applications/striptape.app

