#!/bin/bash

echo "🔄 ClipboardManager Permission Reset Utility"
echo "============================================"
echo ""
echo "This script will completely reset all ClipboardManager permissions"
echo "by clearing both app-level and system-level permission caches."
echo ""

# Check if running with proper permissions
if [ "$EUID" -eq 0 ]; then
    echo "⚠️  Warning: Running as root. This may cause permission issues."
    echo "   It's recommended to run this script as a regular user."
    echo ""
fi

echo "🔍 Checking if ClipboardManager is running..."
if pgrep -f "ClipboardManager" > /dev/null; then
    echo "⏹️  ClipboardManager is running. Attempting to quit..."
    pkill -f "ClipboardManager"
    sleep 2
    
    if pgrep -f "ClipboardManager" > /dev/null; then
        echo "❌ Could not quit ClipboardManager. Please quit it manually and run this script again."
        exit 1
    fi
    echo "✅ ClipboardManager quit successfully"
else
    echo "✅ ClipboardManager is not running"
fi

echo ""
echo "🧹 Clearing app-level permission caches..."

# Clear UserDefaults for ClipboardManager
defaults delete com.yourcompany.clipboardmanager 2>/dev/null || echo "   No app preferences found (this is normal for first run)"

# Clear app-specific permission caches
defaults delete com.yourcompany.clipboardmanager ClipboardManager_AccessibilityGranted 2>/dev/null
defaults delete com.yourcompany.clipboardmanager ClipboardManager_PermissionCheckPerformed 2>/dev/null  
defaults delete com.yourcompany.clipboardmanager ClipboardManager_SkipPermissionPrompts 2>/dev/null
defaults delete com.yourcompany.clipboardmanager ClipboardManager_AppVersion 2>/dev/null
defaults delete com.yourcompany.clipboardmanager ClipboardManager_PermissionsReset 2>/dev/null

echo "✅ App-level caches cleared"

echo ""
echo "🔐 System-level permission reset..."
echo "   Note: System-level permission databases require admin access to modify."
echo "   ClipboardManager will need to be re-approved in System Preferences."

# Try to clear system accessibility database (requires admin access)
if sudo -n true 2>/dev/null; then
    echo "   Attempting to reset system accessibility database..."
    sudo tccutil reset Accessibility 2>/dev/null || echo "   System database reset requires newer macOS version"
    sudo tccutil reset SystemPolicyAllFiles 2>/dev/null || echo "   Full disk access reset not available"
else
    echo "   Admin access not available - system database will not be cleared"
    echo "   You'll need to manually remove ClipboardManager from:"
    echo "   • System Preferences > Privacy & Security > Accessibility"
    echo "   • System Preferences > Privacy & Security > Full Disk Access (if present)"
fi

echo ""
echo "🔄 Additional cleanup..."

# Clear any cached permission decisions
rm -rf ~/Library/Caches/com.yourcompany.clipboardmanager 2>/dev/null
rm -rf ~/Library/Application\ Support/ClipboardManager/permissions.cache 2>/dev/null

echo "✅ Additional cleanup complete"

echo ""
echo "🎉 Permission reset complete!"
echo ""
echo "Next steps:"
echo "1. Launch ClipboardManager"
echo "2. Grant accessibility permissions when prompted"
echo "3. Test paste functionality"
echo ""
echo "If you still have issues:"
echo "• Check System Preferences > Privacy & Security > Accessibility"
echo "• Make sure ClipboardManager is listed and enabled"
echo "• Try the 'Reset Permissions' option in the app menu"
