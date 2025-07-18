#!/usr/bin/env bash

# Simple DMG Builder for ClipboardManager - Icon Testing
# Creates a minimal DMG with proper app icon support

set -e

# Configuration
APP_NAME="ClipboardManager"
VERSION="1.0.2"
DMG_NAME="${APP_NAME}-${VERSION}-Test"
TEMP_DIR="simple_dmg_temp"
FINAL_DMG="${DMG_NAME}.dmg"

echo "🎯 Building Simple Test DMG for ClipboardManager"
echo "==============================================="

# Clean up previous builds
echo "🧹 Cleaning up..."
rm -rf "$TEMP_DIR"
rm -f "$FINAL_DMG"

# Create temp directory structure
echo "📁 Setting up DMG structure..."
mkdir -p "$TEMP_DIR"

# Create app bundle
APP_BUNDLE="$TEMP_DIR/${APP_NAME}.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy the working executable from temp (since compilation is failing)
if [ -f "/tmp/ClipboardManager_FINAL.app/Contents/MacOS/ClipboardManager" ]; then
    echo "📋 Copying working executable from test app..."
    cp "/tmp/ClipboardManager_FINAL.app/Contents/MacOS/ClipboardManager" "$APP_BUNDLE/Contents/MacOS/"
    
    # Copy existing resources
    if [ -d "/tmp/ClipboardManager_FINAL.app/Contents/Resources" ]; then
        cp -R "/tmp/ClipboardManager_FINAL.app/Contents/Resources/"* "$APP_BUNDLE/Contents/Resources/"
    fi
    
    # Copy entitlements if present
    if [ -f "/tmp/ClipboardManager_FINAL.app/Contents/ClipboardManager.entitlements" ]; then
        cp "/tmp/ClipboardManager_FINAL.app/Contents/ClipboardManager.entitlements" "$APP_BUNDLE/Contents/"
    fi
else
    echo "❌ No working executable found. Please ensure the app is built first."
    exit 1
fi

# Create comprehensive Info.plist with proper metadata
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
    <key>CFBundleSignature</key>
    <string>CMgr</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>© 2025 ClipboardManager. All rights reserved.</string>
</dict>
</plist>
EOF

# Touch the app bundle to update modification time
echo "🔄 Updating app bundle timestamp..."
touch "$APP_BUNDLE"
touch "$APP_BUNDLE/Contents"
touch "$APP_BUNDLE/Contents/Resources"

# Create Applications symlink
echo "🔗 Creating Applications link..."
ln -sf /Applications "$TEMP_DIR/Applications"

# Calculate required size
echo "📏 Calculating DMG size..."
SIZE=$(du -sk "$TEMP_DIR" | cut -f1)
SIZE=$((SIZE + 1024))  # Add minimal padding

# Create read-write DMG
echo "💿 Creating DMG..."
hdiutil create -srcfolder "$TEMP_DIR" -volname "$DMG_NAME" -fs HFS+ -format UDZO -imagekey zlib-level=9 "$FINAL_DMG"

# Clean up
echo "🧹 Cleaning up..."
rm -rf "$TEMP_DIR"

# Success message
if [ -f "$FINAL_DMG" ]; then
    FILE_SIZE=$(ls -lh "$FINAL_DMG" | awk '{print $5}')
    echo "🎉 SUCCESS! Simple DMG created"
    echo "📦 File: ${FINAL_DMG}"
    echo "📏 Size: ${FILE_SIZE}"
    echo "📍 Location: $(pwd)/${FINAL_DMG}"
    echo ""
    echo "🚀 Ready for testing app icon functionality!"
else
    echo "❌ Failed to create DMG"
    exit 1
fi
