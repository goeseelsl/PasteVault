#!/usr/bin/env bash

# Professional DMG Builder for ClipboardManager
# Creates a beautiful, professional DMG installer

set -e

# Configuration
APP_NAME="ClipboardManager"
VERSION="1.0.3"
DMG_NAME="${APP_NAME}-${VERSION}"
TEMP_DIR="dmg_build_temp"
FINAL_DMG="${DMG_NAME}.dmg"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🎯 Building Professional ClipboardManager DMG${NC}"
echo -e "${BLUE}=============================================${NC}"

# Clean up any old builds and temp files
echo -e "${YELLOW}🧹 Cleaning up previous builds and temp files...${NC}"
rm -rf "$TEMP_DIR"
rm -f "$FINAL_DMG"
rm -f "temp_${FINAL_DMG}"
rm -rf .build/release  # Force fresh build

# Always build fresh release binary from current source
echo -e "${YELLOW}🔨 Building fresh release binary from current source...${NC}"
# Clean previous builds to ensure fresh compilation
rm -rf .build/release
swift build -c release --verbose

# Verify the build succeeded
if [ ! -f ".build/release/${APP_NAME}" ]; then
    echo -e "${RED}❌ Build failed. Please check for compilation errors.${NC}"
    exit 1
fi

# Create temp directory structure
echo -e "${YELLOW}📁 Setting up DMG structure...${NC}"
mkdir -p "$TEMP_DIR"

# Create app bundle
APP_BUNDLE="$TEMP_DIR/${APP_NAME}.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable from fresh build
echo -e "${YELLOW}📋 Copying fresh release executable...${NC}"
cp ".build/release/${APP_NAME}" "$APP_BUNDLE/Contents/MacOS/"
chmod +x "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"

# Copy the fresh SPM resource bundle containing processed assets
echo -e "${YELLOW}📦 Copying fresh resource bundle...${NC}"
if [ -d ".build/release/ClipboardManager_ClipboardManager.bundle" ]; then
    cp -R ".build/release/ClipboardManager_ClipboardManager.bundle" "$APP_BUNDLE/Contents/Resources/"
    echo -e "${GREEN}✅ Fresh resource bundle copied${NC}"
else
    echo -e "${RED}❌ Warning: No resource bundle found in fresh build${NC}"
    echo -e "${YELLOW}📦 Attempting to build resources manually...${NC}"
    # Try to process resources manually if bundle is missing
    if [ -d "ClipboardManager/Assets.xcassets" ]; then
        mkdir -p "$APP_BUNDLE/Contents/Resources/ClipboardManager_ClipboardManager.bundle"
        cp -R "ClipboardManager/Assets.xcassets" "$APP_BUNDLE/Contents/Resources/ClipboardManager_ClipboardManager.bundle/"
        echo -e "${GREEN}✅ Raw assets copied${NC}"
    fi
fi

# Extract app icons from the fresh build
echo -e "${YELLOW}🎨 Setting up app icons from fresh build...${NC}"
ICON_SET_PATH="$APP_BUNDLE/Contents/Resources/ClipboardManager_ClipboardManager.bundle/Assets.xcassets/AppIcon.appiconset"

if [ -f "$ICON_SET_PATH/1024-mac.png" ]; then
    # Copy the main app icon directly to Resources
    cp "$ICON_SET_PATH/1024-mac.png" "$APP_BUNDLE/Contents/Resources/AppIcon.png"
    echo -e "${GREEN}✅ Added fresh AppIcon.png${NC}"
    
    # Try to create a simple .icns using sips (built into macOS)
    echo -e "${YELLOW}🔧 Creating .icns file with sips...${NC}"
    if sips -s format icns "$ICON_SET_PATH/1024-mac.png" --out "$APP_BUNDLE/Contents/Resources/AppIcon.icns" 2>/dev/null; then
        echo -e "${GREEN}✅ Created fresh AppIcon.icns with sips${NC}"
    else
        echo -e "${YELLOW}⚠️  sips failed, using PNG only${NC}"
    fi
elif [ -f "ClipboardManager/Assets.xcassets/AppIcon.appiconset/1024-mac.png" ]; then
    # Fallback to source assets
    echo -e "${YELLOW}🎨 Using source assets for icons...${NC}"
    cp "ClipboardManager/Assets.xcassets/AppIcon.appiconset/1024-mac.png" "$APP_BUNDLE/Contents/Resources/AppIcon.png"
    if sips -s format icns "ClipboardManager/Assets.xcassets/AppIcon.appiconset/1024-mac.png" --out "$APP_BUNDLE/Contents/Resources/AppIcon.icns" 2>/dev/null; then
        echo -e "${GREEN}✅ Created AppIcon.icns from source assets${NC}"
    fi
else
    echo -e "${RED}❌ Warning: No app icon found in fresh build or source${NC}"
fi

# Create comprehensive Info.plist with proper metadata and permissions
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
    
    <!-- Essential Permission Descriptions -->
    <key>NSAppleEventsUsageDescription</key>
    <string>ClipboardManager needs AppleEvents access to send paste commands and interact with other applications for clipboard functionality.</string>
    <key>NSSystemExtensionUsageDescription</key>
    <string>ClipboardManager needs system access to monitor clipboard changes and keyboard events.</string>
    
    <!-- Accessibility Permission - Critical for keyboard monitoring -->
    <key>NSAccessibilityUsageDescription</key>
    <string>ClipboardManager requires accessibility access to monitor keyboard shortcuts (like Enter key for paste) and clipboard changes. This enables core functionality like paste-on-enter and hotkey detection.</string>
    
    <!-- Input Monitoring Permission - For keyboard events -->
    <key>NSInputMonitoringUsageDescription</key>
    <string>ClipboardManager needs to monitor keyboard input to detect paste shortcuts (Enter key) and custom hotkeys for clipboard management.</string>
    
    <!-- Sandbox Entitlements -->
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
</dict>
</plist>
EOF

# Copy entitlements from source
echo -e "${YELLOW}📋 Copying entitlements from source...${NC}"
if [ -f "ClipboardManager/ClipboardManager.entitlements" ]; then
    cp "ClipboardManager/ClipboardManager.entitlements" "$APP_BUNDLE/Contents/"
    echo -e "${GREEN}✅ Copied entitlements from source${NC}"
else
    echo -e "${YELLOW}⚠️  No entitlements file found in source${NC}"
fi

# Touch the app bundle to update modification time (helps with icon cache refresh)
echo -e "${YELLOW}🔄 Updating app bundle timestamp...${NC}"
touch "$APP_BUNDLE"
touch "$APP_BUNDLE/Contents"
touch "$APP_BUNDLE/Contents/Resources"

# Create Applications symlink
echo -e "${YELLOW}🔗 Creating Applications link...${NC}"
ln -sf /Applications "$TEMP_DIR/Applications"

# Create installation guide
echo -e "${YELLOW}📖 Creating installation guide...${NC}"
cat > "$TEMP_DIR/Installation Guide.rtf" << 'EOF'
{\rtf1\ansi\ansicpg1252\cocoartf2639
{\fonttbl\f0\fswiss\fcharset0 Helvetica-Bold;\f1\fswiss\fcharset0 Helvetica;}
{\colortbl;\red255\green255\blue255;\red0\green0\blue0;\red25\green25\blue25;\red200\green0\blue0;}
{\*\expandedcolortbl;;\cssrgb\c0\c0\c0;\cssrgb\c12941\c12941\c12941;\cssrgb\c82745\c0\c0;}
\margl1440\margr1440\vieww11520\viewh8400\viewkind0
\pard\tx566\tx1133\tx1700\tx2267\tx2834\tx3401\tx3968\tx4535\tx5102\tx5669\tx6236\tx6803\pardirnatural\partightenfactor0

\f0\b\fs28 \cf2 ClipboardManager v${VERSION}\
Installation Guide\

\f1\b0\fs24 \cf3 \
\pard\tx566\tx1133\tx1700\tx2267\tx2834\tx3401\tx3968\tx4535\tx5102\tx5669\tx6236\tx6803\pardirnatural\partightenfactor0

\f0\b \cf2 INSTALLATION:\

\f1\b0 \cf3 1. Drag ClipboardManager.app to the Applications folder\
2. Launch ClipboardManager from Applications\
3. 

\f0\b \cf4 IMPORTANT: Grant ALL permissions when prompted!\

\f1\b0 \cf3 \
\

\f0\b \cf2 REQUIRED PERMISSIONS:\

\f1\b0 \cf3 The app will request several permissions. 

\f0\b You MUST approve ALL of them:\

\f1\b0 \cf3 \
\'95 

\f0\b Accessibility Access
\f1\b0 : Required for keyboard monitoring (Enter key paste)\
\'95 

\f0\b Input Monitoring
\f1\b0 : Required for detecting keyboard shortcuts\
\'95 

\f0\b AppleEvents
\f1\b0 : Required for sending paste commands to other apps\
\
If permissions are denied, the app won\'92t work properly.\
\

\f0\b \cf2 TROUBLESHOOTING:\

\f1\b0 \cf3 If paste-on-enter doesn\'92t work:\
1. Go to System Preferences > Security & Privacy > Privacy\
2. Check \'93Accessibility\'94 - ensure ClipboardManager is listed and enabled\
3. Check \'93Input Monitoring\'94 - ensure ClipboardManager is listed and enabled\
4. Restart ClipboardManager after granting permissions\
\

\f0\b \cf2 FEATURES:\

\f1\b0 \cf3 \'95 AES-256 encrypted clipboard history\
\'95 Cross-device iCloud sync (when available)\
\'95 Keyboard shortcuts for quick access\
\'95 Beautiful and intuitive interface\
\'95 Privacy-focused design\
\'95 Dynamic background colors matching source apps\
\'95 Enhanced paste functionality with focus restoration\
\'95 Paste-on-Enter functionality (requires permissions)\
\

\f0\b \cf2 REQUIREMENTS:\

\f1\b0 \cf3 \'95 macOS 12.0 or later\
\'95 Accessibility permissions for clipboard monitoring\
\'95 Input monitoring permissions for keyboard shortcuts\
\

\f0\b \cf2 SUPPORT:\

\f1\b0 \cf3 For help and updates, visit:\
https://github.com/goeseelsl/PasteVault\
\
\'a9 2025 ClipboardManager. All rights reserved.}
EOF

# Create DMG background directory
echo -e "${YELLOW}🎨 Setting up DMG appearance...${NC}"
mkdir -p "$TEMP_DIR/.background"

# Create a professional background using ImageMagick if available, otherwise use a solid color
if command -v convert &> /dev/null; then
    echo -e "${GREEN}🎨 Creating custom background with ImageMagick...${NC}"
    convert -size 600x400 gradient:'#f0f8ff-#e6f3ff' \
            -font Helvetica-Bold -pointsize 24 -fill '#333333' \
            -gravity center -annotate +0-50 'ClipboardManager' \
            -font Helvetica -pointsize 14 -fill '#666666' \
            -gravity center -annotate +0+50 'Secure Clipboard Management' \
            "$TEMP_DIR/.background/background.png"
else
    echo -e "${YELLOW}⚠️  ImageMagick not available, using system tools...${NC}"
    # Create a simple gradient background using built-in macOS tools
    python3 << 'EOF'
from PIL import Image, ImageDraw, ImageFont
import os

# Create a 600x400 image with gradient background
img = Image.new('RGB', (600, 400), color=(240, 248, 255))
draw = ImageDraw.Draw(img)

# Create gradient effect
for y in range(400):
    color_value = int(240 + (255 - 240) * (y / 400))
    draw.line([(0, y), (600, y)], fill=(color_value, color_value, 255))

# Add text
try:
    font_large = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 36)
    font_small = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 18)
except:
    font_large = ImageFont.load_default()
    font_small = ImageFont.load_default()

# Draw text
draw.text((300, 150), 'ClipboardManager', font=font_large, anchor='mm', fill=(51, 51, 51))
draw.text((300, 250), 'Secure Clipboard Management', font=font_small, anchor='mm', fill=(102, 102, 102))

# Save
img.save('dmg_build_temp/.background/background.png')
EOF

    # Fallback if Python/PIL not available
    if [ ! -f "$TEMP_DIR/.background/background.png" ]; then
        echo -e "${YELLOW}Creating simple background...${NC}"
        # Create a solid color background
        osascript << 'EOF'
tell application "Image Events"
    launch
    set bg_image to make new image with properties {dimensions:{600, 400}}
    save bg_image as PNG in POSIX file (system attribute "PWD") & "/dmg_build_temp/.background/background.png"
end tell
EOF
    fi
fi

# Calculate required size
echo -e "${YELLOW}📏 Calculating DMG size...${NC}"
SIZE=$(du -sk "$TEMP_DIR" | cut -f1)
SIZE=$((SIZE + 2048))  # Add padding

# Create read-write DMG
echo -e "${YELLOW}💿 Creating temporary DMG...${NC}"
hdiutil create -srcfolder "$TEMP_DIR" -volname "$DMG_NAME" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size ${SIZE}k "temp_${FINAL_DMG}"

# Mount for customization
echo -e "${YELLOW}📁 Mounting for customization...${NC}"
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "temp_${FINAL_DMG}" | egrep '^/dev/' | sed 1q | awk '{print $1}')
MOUNT_POINT="/Volumes/$DMG_NAME"

# Wait for mount
sleep 2

# Customize appearance with AppleScript
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
        set icon size of theViewOptions to 96
        
        if exists file ".background:background.png" then
            set background picture of theViewOptions to file ".background:background.png"
        end if
        
        -- Position items
        set position of item "${APP_NAME}.app" of container window to {150, 200}
        set position of item "Applications" of container window to {450, 200}
        
        if exists item "Installation Guide.rtf" then
            set position of item "Installation Guide.rtf" of container window to {300, 320}
        end if
        
        -- Update and close
        update without registering applications
        delay 3
        close
    end tell
end tell
EOF

# Unmount
echo -e "${YELLOW}📤 Unmounting DMG...${NC}"
hdiutil detach "$DEVICE"

# Convert to compressed read-only DMG
echo -e "${YELLOW}🗜️  Creating final compressed DMG...${NC}"
hdiutil convert "temp_${FINAL_DMG}" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG"

# Clean up
echo -e "${YELLOW}🧹 Cleaning up...${NC}"
rm -f "temp_${FINAL_DMG}"
rm -rf "$TEMP_DIR"

# Success message
if [ -f "$FINAL_DMG" ]; then
    FILE_SIZE=$(ls -lh "$FINAL_DMG" | awk '{print $5}')
    echo -e "${GREEN}🎉 SUCCESS! Professional DMG created${NC}"
    echo -e "${GREEN}📦 File: ${FINAL_DMG}${NC}"
    echo -e "${GREEN}📏 Size: ${FILE_SIZE}${NC}"
    echo -e "${GREEN}📍 Location: $(pwd)/${FINAL_DMG}${NC}"
    echo ""
    echo -e "${BLUE}🚀 Ready for distribution!${NC}"
    echo -e "${BLUE}Users can now install ClipboardManager by:${NC}"
    echo -e "${BLUE}  1. Double-clicking the DMG file${NC}"
    echo -e "${BLUE}  2. Dragging the app to Applications${NC}"
    echo -e "${BLUE}  3. Launching from Applications folder${NC}"
else
    echo -e "${RED}❌ Failed to create DMG${NC}"
    exit 1
fi
