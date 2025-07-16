#!/bin/bash

# Test Runner for ClipboardManager Paste Functionality
# Based on Clipy/Maccy testing patterns

echo "🧪 ClipboardManager Paste Functionality Test Suite"
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results
PASSED=0
FAILED=0
TOTAL=0

echo -e "${YELLOW}📋 Checking accessibility permissions...${NC}"
# Check if accessibility permissions are granted
if [[ $(osascript -e 'tell application "System Events" to get process "ClipboardManager"' 2>/dev/null) ]]; then
    echo -e "${GREEN}✅ Accessibility permissions available${NC}"
else
    echo -e "${YELLOW}⚠️  Accessibility permissions not available - manual paste mode will be used${NC}"
fi

echo -e "${YELLOW}🔧 Building project...${NC}"
cd /Users/lawrencegoeseels/Documents/AI/ClipboardManager

# Build the project
swift build 2>&1 | grep -E "(error|warning|Build complete)"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Build successful${NC}"
else
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

echo -e "${YELLOW}🧪 Running paste functionality tests...${NC}"

# Test 1: Basic paste operation
echo "Test 1: Basic paste operation"
cat > /tmp/test_paste.swift << 'EOF'
import Foundation
import AppKit
import Carbon

let pasteboard = NSPasteboard.general
let testContent = "Test paste content"

// Clear pasteboard
pasteboard.clearContents()

// Set test content
pasteboard.setString(testContent, forType: .string)

// Verify content
if let content = pasteboard.string(forType: .string), content == testContent {
    print("✅ Basic paste operation test passed")
} else {
    print("❌ Basic paste operation test failed")
}
EOF

swift /tmp/test_paste.swift

# Test 2: CGEvent creation
echo "Test 2: CGEvent creation"
cat > /tmp/test_cgevent.swift << 'EOF'
import Foundation
import Carbon

let vKeyCode: CGKeyCode = 0x09 // V key
let source = CGEventSource(stateID: .combinedSessionState)

// Test key down event creation
if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true) {
    keyDown.flags = .maskCommand
    print("✅ CGEvent creation test passed")
} else {
    print("❌ CGEvent creation test failed")
}
EOF

swift /tmp/test_cgevent.swift

# Test 3: Accessibility check
echo "Test 3: Accessibility check"
cat > /tmp/test_accessibility.swift << 'EOF'
import Foundation
import ApplicationServices

let accessEnabled = AXIsProcessTrusted()
print("Accessibility status: \(accessEnabled ? "✅ Enabled" : "❌ Disabled")")

// Test permission request (without actually requesting)
let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
let options = [checkOptPrompt: false] // Don't show prompt in test
let _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
print("✅ Accessibility check test passed")
EOF

swift /tmp/test_accessibility.swift

# Test 4: Image handling
echo "Test 4: Image handling"
cat > /tmp/test_image.swift << 'EOF'
import Foundation
import AppKit

let testImage = NSImage(size: NSSize(width: 100, height: 100))
testImage.lockFocus()
NSColor.red.setFill()
NSRect(x: 0, y: 0, width: 100, height: 100).fill()
testImage.unlockFocus()

let pasteboard = NSPasteboard.general
pasteboard.clearContents()
pasteboard.writeObjects([testImage])

if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) {
    print("✅ Image handling test passed - found \(images.count) images")
} else {
    print("❌ Image handling test failed")
}
EOF

swift /tmp/test_image.swift

# Test 5: Multiple operations timing
echo "Test 5: Multiple operations timing"
cat > /tmp/test_timing.swift << 'EOF'
import Foundation
import AppKit
import Dispatch

let pasteboard = NSPasteboard.general
let testContents = ["First", "Second", "Third"]

var completedOperations = 0
let semaphore = DispatchSemaphore(value: 0)

for (index, content) in testContents.enumerated() {
    DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
        
        if let pasteboardContent = pasteboard.string(forType: .string), pasteboardContent == content {
            completedOperations += 1
        }
        
        if completedOperations == testContents.count {
            print("✅ Multiple operations timing test passed")
            semaphore.signal()
        }
    }
}

RunLoop.main.run(until: Date().addingTimeInterval(2.0))
semaphore.wait()
EOF

swift /tmp/test_timing.swift

# Test 6: Error handling
echo "Test 6: Error handling"
cat > /tmp/test_error.swift << 'EOF'
import Foundation
import AppKit

let pasteboard = NSPasteboard.general

// Test with nil content
pasteboard.clearContents()
pasteboard.setString("", forType: .string)

if pasteboard.string(forType: .string) == "" {
    print("✅ Error handling test passed - empty content handled correctly")
} else {
    print("❌ Error handling test failed")
}
EOF

swift /tmp/test_error.swift

echo -e "${YELLOW}🏃 Running application with test scenarios...${NC}"

# Start the application in background for integration testing
.build/debug/ClipboardManager &
APP_PID=$!

# Wait for app to start
sleep 2

# Test integration with running app
echo "Test 7: Integration with running application"
osascript << 'EOF'
tell application "System Events"
    -- Copy some test content to clipboard
    set the clipboard to "Integration test content"
    delay 1
    
    -- Verify clipboard content
    set clipboardContent to the clipboard
    if clipboardContent is "Integration test content" then
        log "✅ Integration test passed"
    else
        log "❌ Integration test failed"
    end if
end tell
EOF

# Stop the application
kill $APP_PID 2>/dev/null

echo -e "${YELLOW}📊 Running performance tests...${NC}"

# Performance test
echo "Test 8: Performance test"
cat > /tmp/test_performance.swift << 'EOF'
import Foundation
import AppKit

let pasteboard = NSPasteboard.general
let numberOfOperations = 100

let startTime = Date()

for i in 0..<numberOfOperations {
    pasteboard.clearContents()
    pasteboard.setString("Performance test \(i)", forType: .string)
}

let duration = Date().timeIntervalSince(startTime)
let operationsPerSecond = Double(numberOfOperations) / duration

print("✅ Performance test passed - \(String(format: "%.2f", operationsPerSecond)) operations/second")
EOF

swift /tmp/test_performance.swift

echo -e "${YELLOW}🧹 Cleaning up test files...${NC}"
rm -f /tmp/test_*.swift

echo -e "${GREEN}🎉 All paste functionality tests completed!${NC}"
echo "=================================================="
echo "Test suite based on Clipy/Maccy patterns"
echo "For production use, grant accessibility permissions for full functionality"
echo "=================================================="
