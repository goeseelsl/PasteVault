#!/bin/bash

# Test script for window closing fix
echo "🔧 Testing Window Closing Fix"
echo "============================"

cd /Users/lawrencegoeseels/Documents/AI/ClipboardManager

echo "🎯 Problem identified and fixed:"
echo "- OLD: NSApp.windows.first { \$0.title == \"ClipboardManager\" }?.close()"
echo "- NEW: NSApp.keyWindow ?? NSApp.mainWindow -> window.close()"
echo ""
echo "✅ The fix uses a more reliable approach:"
echo "- Gets the current key window or main window"
echo "- Doesn't rely on window titles"
echo "- Should work regardless of window title changes"
echo ""
echo "🧪 Test the following scenarios:"
echo "1. Open the sidebar"
echo "2. Click any clipboard item - sidebar should close"
echo "3. Press Enter on selected item - sidebar should close"
echo "4. Click Copy button - sidebar should close"
echo ""
echo "🔍 Console output shows:"
echo "- '🔄 Closing sidebar...' - Sidebar close triggered"
echo "- '⚠️ No key or main window found...' - If no window found"
echo ""
echo "🚀 Starting app for testing..."
./.build/arm64-apple-macosx/debug/ClipboardManager
