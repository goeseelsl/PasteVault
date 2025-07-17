#!/bin/bash

# Test script for hotkey fixes after closing sidebar
echo "🧪 Testing hotkey reloading after sidebar close"
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
echo "3. Select an item to paste or press Escape to close the sidebar"
echo "4. Immediately try Cmd+Shift+C again - it should open the sidebar on first try"
echo "5. Repeat a few times to confirm the hotkey is consistently working"
echo ""
echo "🔍 The console log will show detailed diagnostics about hotkey registration"
echo ""

echo "▶️ Running application..."
# Open the built app with full console output
./.build/debug/ClipboardManager
