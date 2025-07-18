#!/bin/bash

# Simple DMG Builder for ClipboardManager
# A lightweight alternative to the full DMG builder

set -e

APP_NAME="ClipboardManager"
VERSION="1.0.0"
DMG_NAME="${APP_NAME}-${VERSION}"

echo "🚀 Building Simple DMG for ClipboardManager..."

# Clean up
rm -rf build_simple
rm -f "${DMG_NAME}-simple.dmg"

# Create build directory
mkdir -p build_simple

# Build the release binary
echo "🔨 Building release binary..."
swift build -c release

# Create app bundle
echo "📦 Creating app bundle..."
APP_BUNDLE="build_simple/${APP_NAME}.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp ".build/release/${APP_NAME}" "$APP_BUNDLE/Contents/MacOS/"

# Create minimal Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.clipboardmanager.app</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>ClipboardManager</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

# Create Applications symlink
ln -sf /Applications "build_simple/Applications"

# Create simple DMG
echo "💿 Creating DMG..."
hdiutil create -volname "$DMG_NAME" -srcfolder "build_simple" -ov -format UDZO "${DMG_NAME}-simple.dmg"

# Clean up
rm -rf build_simple

echo "✅ Simple DMG created: ${DMG_NAME}-simple.dmg"
echo "📍 Size: $(ls -lh "${DMG_NAME}-simple.dmg" | awk '{print $5}')"
