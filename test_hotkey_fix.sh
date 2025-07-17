#!/bin/bash

# Enhanced diagnostic test script for clipboard manager hotkey fix
echo "🧪 Testing hotkey fix implementation"
echo "-------------------------------------"

# Set up test environment
echo "🔧 Building application..."
swift build

# Check if build was successful
if [ $? -ne 0 ]; then
    echo "❌ Build failed! Please check errors above."
    exit 1
fi

echo "✅ Build successful!"
echo ""
echo "📋 Test procedure:"
echo "1. Run the app and verify the menu bar icon appears"
echo "2. Press Cmd+Shift+C to open the sidebar"
echo "3. Select an item to paste"
echo "4. After paste, immediately try Cmd+Shift+C again - it should open the sidebar on first try"
echo "5. Close the sidebar with Escape"
echo "6. Try Cmd+Shift+C again - it should open the sidebar on first try"
echo ""
echo "🔍 The console log will show detailed diagnostics about hotkey registration and window state"
echo ""

echo "▶️ Running application..."
# Open the built app with full console output
./.build/debug/ClipboardManager
