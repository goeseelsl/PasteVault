#!/bin/bash

# Debug script to test paste functionality step by step
echo "🔍 ClipboardManager Paste Debug Test"
echo "===================================="

# Test 1: Basic clipboard operations
echo "Test 1: Basic clipboard operations"
echo "test content for debugging" | pbcopy
echo "✅ Copied test content"

# Test 2: Verify CGEvent can be created
echo "Test 2: CGEvent creation test"
swift << 'EOF'
import Foundation
import Carbon

let vKeyCode: CGKeyCode = 0x09
let source = CGEventSource(stateID: .combinedSessionState)

if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true) {
    keyDown.flags = .maskCommand
    print("✅ CGEvent creation successful")
} else {
    print("❌ CGEvent creation failed")
}
EOF

# Test 3: Test accessibility permissions
echo "Test 3: Accessibility permissions"
swift << 'EOF'
import Foundation
import ApplicationServices

let hasAccess = AXIsProcessTrusted()
print("Accessibility permissions: \(hasAccess ? "✅ Granted" : "❌ Not granted")")
EOF

# Test 4: Test pasteboard operations
echo "Test 4: Pasteboard operations"
swift << 'EOF'
import Foundation
import AppKit

let pasteboard = NSPasteboard.general
let testContent = "Debug paste test content"

pasteboard.clearContents()
pasteboard.declareTypes([.string], owner: nil)
let success = pasteboard.setString(testContent, forType: .string)

if success {
    print("✅ Pasteboard write successful")
    if let content = pasteboard.string(forType: .string) {
        print("✅ Pasteboard read successful: \(content)")
    } else {
        print("❌ Pasteboard read failed")
    }
} else {
    print("❌ Pasteboard write failed")
}
EOF

echo ""
echo "🎯 Manual test instructions:"
echo "1. Open TextEdit or any text editor"
echo "2. Click in the text area to place cursor"
echo "3. Press Cmd+Shift+V to open ClipboardManager"
echo "4. Navigate to the test content and press ENTER"
echo "5. Watch the terminal for debug output"
echo ""
echo "Expected behavior: Content should paste at cursor location"
echo "If not working: Check terminal output for error messages"
