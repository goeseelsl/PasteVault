#!/bin/bash

# ClipboardManager Build Script
# Creates a proper DMG for distribution

set -e

echo "🔨 Building ClipboardManager..."

# Clean any previous builds
rm -rf build/
rm -rf ClipboardManager.dmg

# Create build directory
mkdir -p build

# Build the project
echo "📦 Compiling Swift project..."
swift build -c release

# Copy the executable to build directory
echo "📋 Setting up application bundle..."
mkdir -p "build/ClipboardManager.app/Contents/MacOS"
mkdir -p "build/ClipboardManager.app/Contents/Resources"

# Copy the executable
cp .build/release/ClipboardManager "build/ClipboardManager.app/Contents/MacOS/"

# Create Info.plist
cat > "build/ClipboardManager.app/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ClipboardManager</string>
    <key>CFBundleIdentifier</key>
    <string>com.clipboardmanager.app</string>
    <key>CFBundleName</key>
    <string>ClipboardManager</string>
    VERSION="1.1.9"
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>ClipboardManager needs to send keystrokes to paste clipboard contents.</string>
    <key>NSAccessibilityUsageDescription</key>
    <string>ClipboardManager needs accessibility access to monitor keyboard shortcuts and paste content.</string>
</dict>
</plist>
EOF

# Copy entitlements if they exist
if [ -f "ClipboardManager/ClipboardManager.entitlements" ]; then
    cp "ClipboardManager/ClipboardManager.entitlements" "build/ClipboardManager.app/Contents/"
fi

echo "🎯 Creating DMG..."

# Create a temporary directory for DMG contents
mkdir -p build/dmg

# Copy the app
cp -R "build/ClipboardManager.app" "build/dmg/"

# Create symlink to Applications
ln -sf /Applications "build/dmg/Applications"

# Create the DMG
hdiutil create -volname "ClipboardManager" \
               -srcfolder "build/dmg" \
               -ov \
               -format UDZO \
               "ClipboardManager.dmg"

# Get file size for verification
DMG_SIZE=$(ls -lh ClipboardManager.dmg | awk '{print $5}')

echo "✅ Build complete!"
echo "📦 DMG created: ClipboardManager.dmg (${DMG_SIZE})"
echo "🚀 Ready for distribution"

# Clean up temporary files
rm -rf build/

echo "🏁 Build process finished successfully"
