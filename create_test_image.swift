#!/usr/bin/env swift

import AppKit
import Foundation

// Create a test image and copy it to clipboard
print("📸 Creating test image...")

// Create a simple test image
let image = NSImage(size: NSSize(width: 100, height: 100))
image.lockFocus()
NSColor.blue.set()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 100, height: 100)).fill()
NSColor.white.set()
NSBezierPath(rect: NSRect(x: 25, y: 25, width: 50, height: 50)).fill()
image.unlockFocus()

print("📋 Copying image to clipboard...")
let pasteboard = NSPasteboard.general
pasteboard.clearContents()
let success = pasteboard.writeObjects([image])

if success {
    print("✅ Image successfully copied to clipboard")
    
    // Verify it's there
    if let retrievedImage = pasteboard.readObjects(forClasses: [NSImage.self])?.first as? NSImage {
        print("✅ Image verified in clipboard: \(retrievedImage.size)")
    } else {
        print("❌ Failed to verify image in clipboard")
    }
} else {
    print("❌ Failed to copy image to clipboard")
}

print("🎉 Test complete - check your ClipboardManager!")
