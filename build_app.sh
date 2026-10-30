#!/bin/bash
set -e

echo "🩹 Building striptape for macOS (Release)..."
swift build -c release --product striptape

BIN_PATH="$(swift build -c release --show-bin-path)/striptape"
APP_NAME="striptape.app"
APP_DIR="./build/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

echo "📦 Assembling $APP_NAME bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"

# Copy and strip binary
cp "$BIN_PATH" "$MACOS_DIR/striptape"
strip -x "$MACOS_DIR/striptape"

# Create Info.plist
cat <<EOF > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>striptape</string>
    <key>CFBundleIdentifier</key>
    <string>lab.ductape.striptape</string>
    <key>CFBundleName</key>
    <string>striptape</string>
    <key>CFBundleDisplayName</key>
    <string>striptape</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Ad-hoc code sign for Apple Silicon macOS
if command -v codesign &> /dev/null; then
    echo "🔏 Signing $APP_NAME..."
    codesign --force --deep --sign - "$APP_DIR"
fi

echo "✅ Successfully built $APP_DIR"
echo "👉 You can run it with: open $APP_DIR"

