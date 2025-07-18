#!/bin/bash

# ClipboardManager DMG Builder
# Creates a professional DMG installer for ClipboardManager

set -e  # Exit on any error

# Configuration
APP_NAME="ClipboardManager"
VERSION="1.0.0"
DMG_NAME="${APP_NAME}-${VERSION}"
BUILD_DIR="build"
DMG_DIR="dmg_temp"
FINAL_DMG="${DMG_NAME}.dmg"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Building ClipboardManager DMG Installer${NC}"
echo -e "${BLUE}==========================================${NC}"

# Clean previous builds
echo -e "${YELLOW}🧹 Cleaning previous builds...${NC}"
rm -rf "$BUILD_DIR"
rm -rf "$DMG_DIR"
rm -f "${FINAL_DMG}"

# Create build directory
mkdir -p "$BUILD_DIR"
mkdir -p "$DMG_DIR"

echo -e "${YELLOW}🔨 Building application bundle...${NC}"

# Check if we can build with Xcode (preferred for proper app bundle)
if command -v xcodebuild &> /dev/null; then
    echo -e "${GREEN}✅ Using Xcode to build app bundle${NC}"
    
    # Create Xcode project structure if it doesn't exist
    if [ ! -f "${APP_NAME}.xcodeproj/project.pbxproj" ]; then
        echo -e "${YELLOW}📦 Creating Xcode project structure...${NC}"
        # We'll use swift package generate-xcodeproj or create manually
        if swift package generate-xcodeproj 2>/dev/null; then
            echo -e "${GREEN}✅ Generated Xcode project${NC}"
        else
            echo -e "${YELLOW}⚠️  Swift package generate-xcodeproj not available, creating manual build${NC}"
            # Fall back to manual bundle creation
            create_manual_bundle
        fi
    fi
    
    # Try to build with Xcode
    if [ -f "${APP_NAME}.xcodeproj/project.pbxproj" ]; then
        xcodebuild -project "${APP_NAME}.xcodeproj" -scheme "${APP_NAME}" -configuration Release -derivedDataPath "$BUILD_DIR" build
        
        # Find the built app
        BUILT_APP=$(find "$BUILD_DIR" -name "${APP_NAME}.app" -type d | head -1)
        if [ -n "$BUILT_APP" ]; then
            cp -R "$BUILT_APP" "$DMG_DIR/"
            echo -e "${GREEN}✅ App bundle built successfully${NC}"
        else
            echo -e "${RED}❌ Failed to find built app bundle${NC}"
            create_manual_bundle
        fi
    else
        create_manual_bundle
    fi
else
    echo -e "${YELLOW}⚠️  Xcode not available, creating manual bundle${NC}"
    create_manual_bundle
fi

create_manual_bundle() {
    echo -e "${YELLOW}🔧 Creating manual app bundle...${NC}"
    
    # Build the Swift executable
    swift build -c release
    
    # Create app bundle structure
    APP_BUNDLE="$DMG_DIR/${APP_NAME}.app"
    mkdir -p "$APP_BUNDLE/Contents/MacOS"
    mkdir -p "$APP_BUNDLE/Contents/Resources"
    
    # Copy executable
    cp ".build/release/${APP_NAME}" "$APP_BUNDLE/Contents/MacOS/"
    
    # Create Info.plist
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
    <string>????</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>ClipboardManager needs to monitor clipboard changes to provide clipboard history functionality.</string>
    <key>NSSystemExtensionUsageDescription</key>
    <string>ClipboardManager needs system access to monitor clipboard changes.</string>
</dict>
</plist>
EOF
    
    # Copy assets if they exist
    if [ -d "ClipboardManager/Assets.xcassets" ]; then
        cp -R "ClipboardManager/Assets.xcassets" "$APP_BUNDLE/Contents/Resources/"
    fi
    
    # Copy entitlements
    if [ -f "ClipboardManager/ClipboardManager.entitlements" ]; then
        cp "ClipboardManager/ClipboardManager.entitlements" "$APP_BUNDLE/Contents/"
    fi
    
    echo -e "${GREEN}✅ Manual app bundle created${NC}"
}

# Create Applications symlink
echo -e "${YELLOW}🔗 Creating Applications folder link...${NC}"
ln -sf /Applications "$DMG_DIR/Applications"

# Create README file for the DMG
cat > "$DMG_DIR/README.txt" << EOF
ClipboardManager v${VERSION}

INSTALLATION:
1. Drag ClipboardManager.app to the Applications folder
2. Launch ClipboardManager from Applications
3. Grant accessibility permissions when prompted
4. Enjoy secure clipboard management!

FEATURES:
• AES-256 encrypted clipboard history
• Cross-device iCloud sync (when available)
• Keyboard shortcuts for quick access
• Beautiful and intuitive interface
• Privacy-focused design

REQUIREMENTS:
• macOS 12.0 or later
• Accessibility permissions for clipboard monitoring

For support, visit: https://github.com/goeseelsl/PasteVault

© 2025 ClipboardManager. All rights reserved.
EOF

# Create DMG background image (placeholder - you can replace with custom image)
echo -e "${YELLOW}🎨 Creating DMG background...${NC}"
mkdir -p "$DMG_DIR/.background"

# Create a simple background using built-in tools
osascript << EOF
tell application "Image Events"
    launch
    set this_image to make new image with properties {dimensions:{600, 400}}
    save this_image as JPEG in POSIX file "$(pwd)/$DMG_DIR/.background/background.jpg"
end tell
EOF

# Calculate DMG size
echo -e "${YELLOW}📏 Calculating DMG size...${NC}"
DMG_SIZE=$(du -sk "$DMG_DIR" | cut -f1)
DMG_SIZE=$((DMG_SIZE + 1000))  # Add some padding

# Create temporary DMG
echo -e "${YELLOW}💿 Creating temporary DMG...${NC}"
hdiutil create -srcfolder "$DMG_DIR" -volname "$DMG_NAME" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size ${DMG_SIZE}k "temp_${FINAL_DMG}"

# Mount the temporary DMG
echo -e "${YELLOW}📁 Mounting DMG for customization...${NC}"
MOUNT_DIR=$(hdiutil attach -readwrite -noverify -noautoopen "temp_${FINAL_DMG}" | egrep '^/dev/' | sed 1q | awk '{print $3}')

# Customize DMG appearance
echo -e "${YELLOW}🎨 Customizing DMG appearance...${NC}"
osascript << EOF
tell application "Finder"
    tell disk "$DMG_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 700, 500}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 128
        set background picture of theViewOptions to file ".background:background.jpg"
        
        -- Position icons
        set position of item "${APP_NAME}.app" of container window to {150, 200}
        set position of item "Applications" of container window to {450, 200}
        
        -- Update and close
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF

# Unmount the temporary DMG
echo -e "${YELLOW}📤 Unmounting temporary DMG...${NC}"
hdiutil detach "$MOUNT_DIR"

# Convert to final compressed DMG
echo -e "${YELLOW}🗜️  Creating final compressed DMG...${NC}"
hdiutil convert "temp_${FINAL_DMG}" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG"

# Clean up
echo -e "${YELLOW}🧹 Cleaning up temporary files...${NC}"
rm -f "temp_${FINAL_DMG}"
rm -rf "$BUILD_DIR"
rm -rf "$DMG_DIR"

# Final verification
if [ -f "$FINAL_DMG" ]; then
    DMG_FILE_SIZE=$(ls -lh "$FINAL_DMG" | awk '{print $5}')
    echo -e "${GREEN}🎉 SUCCESS! DMG created successfully${NC}"
    echo -e "${GREEN}📦 File: ${FINAL_DMG}${NC}"
    echo -e "${GREEN}📏 Size: ${DMG_FILE_SIZE}${NC}"
    echo -e "${GREEN}📍 Location: $(pwd)/${FINAL_DMG}${NC}"
    echo ""
    echo -e "${BLUE}🚀 Installation Instructions:${NC}"
    echo -e "${BLUE}  1. Double-click ${FINAL_DMG} to mount${NC}"
    echo -e "${BLUE}  2. Drag ClipboardManager.app to Applications${NC}"
    echo -e "${BLUE}  3. Launch from Applications folder${NC}"
    echo -e "${BLUE}  4. Grant accessibility permissions when prompted${NC}"
else
    echo -e "${RED}❌ Failed to create DMG${NC}"
    exit 1
fi
