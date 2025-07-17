#!/bin/bash

# Test script for clipboard manager image functionality
echo "🧪 Testing ClipboardManager image functionality..."

# First, let's copy a test image to the clipboard
echo "📋 Copying test image to clipboard..."
osascript -e 'tell application "Finder" to set the clipboard to (POSIX file "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertNoteIcon.icns") as alias'

# Wait a moment for the clipboard to be processed
sleep 2

# Check if the image is in the clipboard
echo "🔍 Checking if image is in clipboard..."
osascript -e 'tell application "System Events" to get clipboard info'

echo "✅ Image should now be in your clipboard"
echo "📖 Instructions:"
echo "   1. Open the ClipboardManager organization window"
echo "   2. You should see the image in the list"
echo "   3. Try copying it again using the context menu"
echo "   4. The image should be copied to your clipboard"

# Optional: Check what's in the pasteboard
echo "🔍 Checking pasteboard contents..."
swift -e "
import AppKit
let pb = NSPasteboard.general
print(\"Pasteboard types: \(pb.types ?? [])\")
if let image = pb.readObjects(forClasses: [NSImage.self])?.first as? NSImage {
    print(\"📸 Image found in pasteboard: \(image.size)\")
} else {
    print(\"❌ No image in pasteboard\")
}
"

echo "🎉 Test setup complete!"
