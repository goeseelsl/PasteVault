#!/bin/bash

# Test script for keyboard shortcut behavior after paste operations
echo "🔍 Testing Keyboard Shortcut After Paste Issue"
echo "============================================="

cd /Users/lawrencegoeseels/Documents/AI/ClipboardManager

echo "🎯 Issue identified:"
echo "- After pasting with Enter key, keyboard shortcuts require double press"
echo "- This suggests CGEvent posting in performProgrammaticPaste() is interfering"
echo "- NSEvent monitors might be getting disrupted by the programmatic paste"
echo ""
echo "💡 Potential causes:"
echo "1. CGEvent posting interferes with NSEvent monitor chain"
echo "2. Event source state not properly restored after paste"
echo "3. Focus/responder chain disrupted by programmatic events"
echo ""
echo "🧪 Test sequence:"
echo "1. Open app and toggle sidebar with Cmd+Shift+B (should work)"
echo "2. Select an item and press Enter to paste"
echo "3. Try Cmd+Shift+B again - ISSUE: requires double press"
echo "4. Try clicking the sidebar toggle button - works normally"
echo ""
echo "🔍 Console output to monitor:"
echo "- '🔍 Global shortcut detected' messages"
echo "- '📁 Triggering sidebar toggle' messages"
echo "- '📤 Posting events with cgSessionEventTap...' from paste"
echo "- '✅ Programmatic paste events posted successfully'"
echo ""
echo "🚀 Starting app for testing..."
./.build/debug/ClipboardManager
