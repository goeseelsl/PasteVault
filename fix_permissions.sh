#!/bin/bash

# Permission Reset Script for ClipboardManager
# Run this if you're having permission issues

echo "🔄 Resetting ClipboardManager permissions..."
echo ""

# Function to request permission
request_permission() {
    echo "🔐 Requesting accessibility permission..."
    
    # Create a simple AppleScript to request permissions
    osascript -e '
    tell application "System Events"
        display dialog "ClipboardManager needs accessibility permission to paste content automatically.

This script will open System Settings where you can grant permission.

1. Click OK to open System Settings
2. Find \"ClipboardManager\" in the Accessibility list  
3. Enable the checkbox next to it
4. Restart ClipboardManager

Without this permission, Enter key paste will not work automatically." buttons {"Cancel", "Open System Settings"} default button "Open System Settings"
        
        if button returned of result is "Open System Settings" then
            open location "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        end if
    end tell
    ' 2>/dev/null
}

# Reset any cached permission state
echo "🧹 Clearing permission caches..."
defaults delete com.yourcompany.ClipboardManager 2>/dev/null || true

# Kill any running instances
echo "🛑 Stopping any running ClipboardManager instances..."
pkill -f "ClipboardManager" 2>/dev/null || true
sleep 1

# Request permission
request_permission

echo ""
echo "✅ Permission reset complete!"
echo ""
echo "Next steps:"
echo "1. Grant accessibility permission in System Settings"
echo "2. Restart ClipboardManager"
echo "3. Test Enter key paste functionality"
echo ""
echo "If problems persist, the issue may be:"
echo "- App needs to be in /Applications folder"
echo "- App needs to be code signed properly"
echo "- System security settings preventing automation"
