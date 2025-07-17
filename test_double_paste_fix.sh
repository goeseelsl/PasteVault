#!/bin/bash

# Test script for double paste fix
echo "🔧 Testing Double Paste Fix"
echo "========================="

cd /Users/lawrencegoeseels/Documents/AI/ClipboardManager

echo "🎯 Issue identified and fixed:"
echo "- The performProgrammaticPaste() function was posting paste events twice"
echo "- Once with cgSessionEventTap and once with cgAnnotatedSessionEventTap"
echo "- This caused items to be pasted twice"
echo ""
echo "✅ Solution applied:"
echo "- Removed the duplicate cgAnnotatedSessionEventTap posting"
echo "- Now only uses cgSessionEventTap for paste events"
echo "- Should paste items only once"
echo ""
echo "🧪 Test scenarios:"
echo "1. Open the sidebar"
echo "2. Try these operations:"
echo "   - Click any clipboard item → should paste ONCE"
echo "   - Press Enter on selected item → should paste ONCE"
echo "   - Click Copy button → should only copy to clipboard (no paste)"
echo ""
echo "🔍 Console output to watch for:"
echo "- '📤 Posting events with cgSessionEventTap...'"
echo "- '✅ Programmatic paste events posted successfully'"
echo "- Should NOT see cgAnnotatedSessionEventTap anymore"
echo ""
echo "⚠️ Expected behavior:"
echo "- Copy button: Only copies to clipboard (no paste)"
echo "- Click item: Pastes once"
echo "- Enter key: Pastes once"
echo "- Sidebar closes on all operations"
echo ""
echo "🚀 Starting app for testing..."
./.build/arm64-apple-macosx/debug/ClipboardManager
