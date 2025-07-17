#!/usr/bin/env swift

import Foundation
import AppKit

// Test script to verify image copying functionality
print("🧪 Testing image copying functionality...")

// Create a test image
let image = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)!
let imageData = image.tiffRepresentation!

print("📸 Created test image with \(imageData.count) bytes")

// Test copying image to pasteboard
let pasteboard = NSPasteboard.general
pasteboard.clearContents()

// Method 1: Use writeObjects
print("📋 Testing writeObjects method...")
let success1 = pasteboard.writeObjects([image])
print("✅ writeObjects success: \(success1)")

// Verify image was copied
if let retrievedImage = pasteboard.readObjects(forClasses: [NSImage.self])?.first as? NSImage {
    print("✅ Image successfully retrieved from pasteboard")
    print("📏 Retrieved image size: \(retrievedImage.size)")
} else {
    print("❌ Failed to retrieve image from pasteboard")
}

// Method 2: Use declareTypes and setData
print("\n📋 Testing declareTypes + setData method...")
pasteboard.clearContents()
pasteboard.declareTypes([.tiff, .png], owner: nil)
pasteboard.setData(imageData, forType: .tiff)

if let retrievedData = pasteboard.data(forType: .tiff) {
    print("✅ Image data successfully retrieved from pasteboard")
    print("📏 Retrieved data size: \(retrievedData.count) bytes")
    
    if let retrievedImage = NSImage(data: retrievedData) {
        print("✅ Successfully created NSImage from retrieved data")
        print("📏 Retrieved image size: \(retrievedImage.size)")
    } else {
        print("❌ Failed to create NSImage from retrieved data")
    }
} else {
    print("❌ Failed to retrieve image data from pasteboard")
}

print("\n🎉 Image copying test complete!")
