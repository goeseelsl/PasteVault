#!/bin/bash

echo "Testing Keyboard Shortcuts for ClipboardManager"
echo "================================================"

# Check if app is running
if pgrep -x "ClipboardManager" > /dev/null; then
    echo "✅ ClipboardManager is running"
else
    echo "❌ ClipboardManager is not running"
    echo "Starting ClipboardManager..."
    open -a ClipboardManager
    sleep 3
fi

echo ""
echo "Testing Sidebar Toggle (Cmd+Shift+B):"
echo "--------------------------------------"

# Test sidebar toggle multiple times
for i in {1..5}; do
    echo "Test $i: Pressing Cmd+Shift+B"
    
    # Use AppleScript to simulate key press
    osascript <<EOF
tell application "System Events"
    tell process "ClipboardManager"
        key code 11 using {command down, shift down}
    end tell
end tell
EOF
    
    sleep 1
    echo "  -> Sidebar should toggle"
    sleep 1
done

echo ""
echo "Testing Other Shortcuts:"
echo "------------------------"

echo "Testing Cmd+Shift+V (Show clipboard history):"
osascript <<EOF
tell application "System Events"
    tell process "ClipboardManager"
        key code 9 using {command down, shift down}
    end tell
end tell
EOF

sleep 2

echo "Testing Cmd+Shift+F (Show search):"
osascript <<EOF
tell application "System Events"
    tell process "ClipboardManager"
        key code 3 using {command down, shift down}
    end tell
end tell
EOF

sleep 2

echo ""
echo "Test completed!"
echo "Please observe the sidebar behavior and let me know if:"
echo "1. The sidebar toggles immediately on first Cmd+Shift+B press"
echo "2. Subsequent presses also toggle immediately (no double-press required)"
echo "3. Other shortcuts work as expected"
