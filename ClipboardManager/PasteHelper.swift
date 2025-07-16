import Foundation
import AppKit
import Carbon

/// Helper class for paste functionality to avoid circular dependencies
class PasteHelper {
    
    private static var isOperationInProgress = false
    private static let operationQueue = DispatchQueue(label: "paste-operations", qos: .userInteractive)
    
    /// Perform paste operation with content from clipboard item
    /// - Parameter item: The clipboard item to paste
    static func paste(item: ClipboardItem) {
        print("🚀 Starting reliable paste operation for item: \(item.content?.prefix(30) ?? "Image")")
        
        guard AccessibilityHelper.checkAccessibilityPermissions() else {
            print("❌ Accessibility permissions denied")
            return
        }
        
        // Prevent multiple operations from interfering with each other
        operationQueue.async {
            performPasteOperation(item: item)
        }
    }
    
    private static func performPasteOperation(item: ClipboardItem) {
        guard !isOperationInProgress else {
            print("⚠️ Paste operation already in progress, skipping")
            return
        }
        
        isOperationInProgress = true
        defer { isOperationInProgress = false }
        
        // Save current clipboard state
        let previousContent = getCurrentClipboardContent()
        print("💾 Saved previous clipboard content")
        
        // Set the item content to clipboard
        setClipboardContent(item: item)
        print("📋 Set new content to clipboard")
        
        // Small delay to ensure clipboard is updated
        Thread.sleep(forTimeInterval: 0.1)
        
        // Perform the paste operation
        let pasteSuccess = performActualPaste()
        print("✅ Paste operation completed: \(pasteSuccess)")
        
        // Restore previous clipboard content after a delay
        Thread.sleep(forTimeInterval: 0.3)
        restoreClipboardContent(previousContent)
        print("🔄 Previous clipboard content restored")
    }
    
    /// Simple paste function for backward compatibility
    static func paste() {
        print("📝 Starting simple paste operation")
        operationQueue.async {
            _ = performActualPaste()
        }
    }
    
    // MARK: - Clipboard Management
    
    private struct ClipboardContent {
        let text: String?
        let image: NSImage?
        let data: Data?
        let type: NSPasteboard.PasteboardType?
    }
    
    private static func getCurrentClipboardContent() -> ClipboardContent {
        let pasteboard = NSPasteboard.general
        
        if let image = pasteboard.readObjects(forClasses: [NSImage.self])?.first as? NSImage {
            return ClipboardContent(text: nil, image: image, data: nil, type: .tiff)
        } else if let string = pasteboard.string(forType: .string) {
            return ClipboardContent(text: string, image: nil, data: nil, type: .string)
        } else if let data = pasteboard.data(forType: .tiff) {
            return ClipboardContent(text: nil, image: nil, data: data, type: .tiff)
        } else {
            return ClipboardContent(text: "", image: nil, data: nil, type: .string)
        }
    }
    
    private static func setClipboardContent(item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        // Small delay to ensure clear is processed
        Thread.sleep(forTimeInterval: 0.05)
        
        if let imageData = item.imageData, let image = NSImage(data: imageData) {
            // Handle image content
            print("📸 Setting image content to clipboard")
            let success = pasteboard.writeObjects([image])
            print("📸 Image write success: \(success)")
        } else if let content = item.content {
            // Handle text content
            print("📝 Setting text content to clipboard: \(content.prefix(50))...")
            let success = pasteboard.setString(content, forType: .string)
            print("📝 Text write success: \(success)")
        }
        
        // Verify content was set
        Thread.sleep(forTimeInterval: 0.05)
        let verifyContent = pasteboard.string(forType: .string) ?? "No text content"
        print("🔍 Clipboard verification: \(verifyContent.prefix(30))...")
    }
    
    private static func restoreClipboardContent(_ content: ClipboardContent) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        // Small delay to ensure clear is processed
        Thread.sleep(forTimeInterval: 0.05)
        
        if let image = content.image {
            let success = pasteboard.writeObjects([image])
            print("🔄 Restored image content: \(success)")
        } else if let text = content.text {
            let success = pasteboard.setString(text, forType: .string)
            print("🔄 Restored text content: \(success) - \(text.prefix(30))...")
        } else if let data = content.data, let type = content.type {
            pasteboard.setData(data, forType: type)
            print("🔄 Restored data content of type: \(type)")
        }
    }
    
    // MARK: - Reliable Paste Implementation
    
    private static func performActualPaste() -> Bool {
        print("🎯 Executing paste operation")
        
        // First try AppleScript approach (most reliable)
        if performAppleScriptPaste() {
            print("✅ AppleScript paste succeeded")
            return true
        }
        
        // Fallback to CGEvent approach
        print("⚡ Falling back to CGEvent paste")
        return performCGEventPaste()
    }
    
    private static func performAppleScriptPaste() -> Bool {
        let script = """
        tell application "System Events"
            key code 9 using command down
        end tell
        """
        
        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        let result = appleScript?.executeAndReturnError(&error)
        
        if let error = error {
            print("❌ AppleScript error: \(error)")
            return false
        }
        
        return result != nil
    }
    
    private static func performCGEventPaste() -> Bool {
        print("🔑 Performing CGEvent paste")
        
        // Create event source
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            print("❌ Failed to create event source")
            return false
        }
        
        // Get the V key code (works for all keyboard layouts)
        let vKeyCode: CGKeyCode = 9
        
        // Create key down and up events for CMD+V
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            print("❌ Failed to create key events")
            return false
        }
        
        // Set command modifier
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        
        // Post the events
        keyDown.post(tap: .cgSessionEventTap)
        Thread.sleep(forTimeInterval: 0.05)  // Small delay between key down and up
        keyUp.post(tap: .cgSessionEventTap)
        
        print("✅ CGEvent paste completed")
        return true
    }
}
