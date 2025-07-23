import Foundation
import AppKit
import Carbon

/// Helper class for paste functionality with comprehensive logging for debugging
class PasteHelper {
    
    private static var isOperationInProgress = false
    private static let operationQueue = DispatchQueue(label: "paste-operations", qos: .userInteractive)
    private static var previousActiveApp: NSRunningApplication?
    private static var debugLog: [String] = []
    
    // Cursor position preservation
    private static var previousFocusedElement: AXUIElement?
    private static var previousSelectedTextRange: CFTypeRef?
    private static var originalCursorLocation: Int = 0
    
    // MARK: - Debug Logging
    
    /// Add a debug log entry with timestamp (accessible to other classes)
    static func log(_ message: String, level: LogLevel = .info) {
        let timestamp = DateFormatter.debugFormatter.string(from: Date())
        let logEntry = "[\(timestamp)] [\(level.rawValue)] \(message)"
        debugLog.append(logEntry)
        
        // Print to console for immediate debugging
        print(logEntry)
        
        // Keep only last 100 entries to prevent memory issues
        if debugLog.count > 100 {
            debugLog.removeFirst(debugLog.count - 100)
        }
    }
    
    /// Get debug logs for troubleshooting
    static func getDebugLogs() -> String {
        return debugLog.joined(separator: "\n")
    }
    
    /// Clear debug logs
    static func clearDebugLogs() {
        debugLog.removeAll()
        log("Debug logs cleared", level: .info)
    }
    
    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"
    }
    
    /// Perform paste operation with content from clipboard item
    /// - Parameter item: The clipboard item to paste
    static func paste(item: ClipboardItem) {
        log("🚀 Starting ENHANCED paste operation for item: \(item.content?.prefix(30) ?? "Image")", level: .info)
        
        // Log current system state
        logSystemState()
        
        guard AccessibilityHelper.checkAccessibilityPermissions() else {
            log("❌ Accessibility permissions denied", level: .error)
            return
        }
        
        // Prevent multiple operations from interfering with each other
        operationQueue.async {
            performPasteOperation(item: item)
        }
    }
    
    /// Log current system state for debugging
    private static func logSystemState() {
        log("=== SYSTEM STATE DEBUG ===", level: .debug)
        
        // Current active applications
        let activeApps = NSWorkspace.shared.runningApplications.filter { $0.isActive }
        log("Active applications: \(activeApps.map { $0.localizedName ?? "Unknown" }.joined(separator: ", "))", level: .debug)
        
        // Current frontmost application
        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            log("Frontmost app: \(frontmostApp.localizedName ?? "Unknown") [\(frontmostApp.bundleIdentifier ?? "no-bundle-id")]", level: .debug)
        }
        
        // Current key window
        if let keyWindow = NSApp.keyWindow {
            log("Key window: \(keyWindow.title) [Level: \(keyWindow.level.rawValue)]", level: .debug)
        } else {
            log("No key window", level: .debug)
        }
        
        // Current focused element (if accessible)
        logFocusedElement()
        
        log("=== END SYSTEM STATE ===", level: .debug)
    }
    
    /// Log the currently focused UI element
    private static func logFocusedElement() {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        
        let result = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        if result == .success, let element = focusedElement {
            var role: CFTypeRef?
            var value: CFTypeRef?
            
            AXUIElementCopyAttributeValue(element as! AXUIElement, kAXRoleAttribute as CFString, &role)
            AXUIElementCopyAttributeValue(element as! AXUIElement, kAXValueAttribute as CFString, &value)
            
            log("Focused element - Role: \(role as? String ?? "unknown"), Value: \(value as? String ?? "none")", level: .debug)
        } else {
            log("Could not get focused element, result: \(result.rawValue)", level: .debug)
        }
    }
    
    /// Store reference to the previously active application for focus restoration
    static func storePreviousActiveApp() {
        log("📍 STORING previous active app...", level: .debug)
        
        // First, try to get the frontmost application before checking isActive
        let ourBundleId = Bundle.main.bundleIdentifier
        
        // Log all running apps for debugging
        let apps = NSWorkspace.shared.runningApplications
        log("🔍 Found \(apps.count) running applications", level: .debug)
        
        // Strategy 1: Find currently active app (excluding our app)
        for app in apps {
            if app.isActive && app.bundleIdentifier != ourBundleId {
                previousActiveApp = app
                log("💾 Stored active app: \(app.localizedName ?? "Unknown") [\(app.bundleIdentifier ?? "no-bundle-id")]", level: .info)
                return
            }
        }
        
        // Strategy 2: Try frontmost application
        if let frontmost = NSWorkspace.shared.frontmostApplication, 
           frontmost.bundleIdentifier != ourBundleId {
            previousActiveApp = frontmost
            log("💾 Stored frontmost app as fallback: \(frontmost.localizedName ?? "Unknown") [\(frontmost.bundleIdentifier ?? "no-bundle-id")]", level: .info)
            return
        }
        
        // Strategy 3: Find most recently used non-ClipboardManager app
        let sortedApps = apps
            .filter { $0.bundleIdentifier != ourBundleId && $0.activationPolicy == .regular }
            .sorted { app1, app2 in
                // Sort by launch date (most recent first)
                let date1 = app1.launchDate ?? Date.distantPast
                let date2 = app2.launchDate ?? Date.distantPast
                return date1 > date2
            }
        
        if let mostRecent = sortedApps.first {
            previousActiveApp = mostRecent
            log("💾 Stored most recent app as last resort: \(mostRecent.localizedName ?? "Unknown") [\(mostRecent.bundleIdentifier ?? "no-bundle-id")]", level: .info)
            return
        }
        
        // Strategy 4: If all else fails, use Finder as default
        let finder = apps.first { $0.bundleIdentifier == "com.apple.finder" }
        if let finder = finder {
            previousActiveApp = finder
            log("💾 Using Finder as ultimate fallback", level: .info)
            return
        }
        
        log("⚠️ Could not find any app to store as previous active", level: .warning)
    }
    
    /// Store the current cursor position and focused element for restoration
    static func storePreviousCursorPosition() {
        log("🎯 STORING cursor position...", level: .debug)
        
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        
        let result = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        if result == .success, let element = focusedElement {
            previousFocusedElement = (element as! AXUIElement)
            
            // Try to get the selected text range
            var selectedTextRange: CFTypeRef?
            let rangeResult = AXUIElementCopyAttributeValue(previousFocusedElement!, kAXSelectedTextRangeAttribute as CFString, &selectedTextRange)
            
            if rangeResult == .success {
                previousSelectedTextRange = selectedTextRange
                
                // Extract the location value for more precise restoration
                if let range = selectedTextRange {
                    var location: CFIndex = 0
                    var length: CFIndex = 0
                    if AXValueGetValue(range as! AXValue, AXValueType.cfRange, &location) {
                        originalCursorLocation = location
                        log("📍 Extracted cursor location: \(location)", level: .debug)
                    }
                }
                
                log("💾 Stored cursor position and selection range", level: .info)
                
                // Log details about what we captured
                if let range = selectedTextRange {
                    log("📍 Stored text range: \(range)", level: .debug)
                }
            } else {
                log("⚠️ Could not get selected text range (error: \(rangeResult.rawValue))", level: .warning)
                previousSelectedTextRange = nil
            }
            
            // Log the focused element details
            var role: CFTypeRef?
            AXUIElementCopyAttributeValue(previousFocusedElement!, kAXRoleAttribute as CFString, &role)
            var value: CFTypeRef?
            AXUIElementCopyAttributeValue(previousFocusedElement!, kAXValueAttribute as CFString, &value)
            
            log("🎯 Focused element - Role: \(role as? String ?? "unknown"), Value preview: \((value as? String)?.prefix(100) ?? "no-value")", level: .debug)
        } else {
            log("❌ Could not get focused element (error: \(result.rawValue))", level: .warning)
            previousFocusedElement = nil
            previousSelectedTextRange = nil
        }
    }
    
    /// Restore the previously stored cursor position
    static func restorePreviousCursorPosition() {
        guard let focusedElement = previousFocusedElement else {
            log("⚠️ No previous cursor position to restore", level: .warning)
            return
        }
        
        log("🎯 RESTORING cursor position to location \(originalCursorLocation)...", level: .debug)
        
        // First, try to focus the element
        let focusResult = AXUIElementSetAttributeValue(focusedElement, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        
        if focusResult == .success {
            log("✅ Successfully focused the element", level: .debug)
            
            // Try multiple times to restore cursor position (paste content might still be processing)
            attemptCursorRestore(element: focusedElement, attempt: 1)
        } else {
            log("❌ Could not focus the element (error: \(focusResult.rawValue))", level: .warning)
        }
    }
    
    /// Attempt to restore cursor position with retries
    private static func attemptCursorRestore(element: AXUIElement, attempt: Int) {
        let maxAttempts = 3
        
        // Create a new CFRange with the original cursor location
        var range = CFRange(location: originalCursorLocation, length: 0)
        let axRange = AXValueCreate(AXValueType.cfRange, &range)
        
        if let axRange = axRange {
            let rangeResult = AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, axRange)
            
            if rangeResult == .success {
                log("✅ Successfully restored cursor position and selection (attempt \(attempt))", level: .info)
                
                // Clean up
                previousFocusedElement = nil
                previousSelectedTextRange = nil
                originalCursorLocation = 0
                return
            } else {
                log("⚠️ Could not restore text selection (attempt \(attempt), error: \(rangeResult.rawValue))", level: .warning)
                
                // Retry if we haven't exceeded max attempts
                if attempt < maxAttempts {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        attemptCursorRestore(element: element, attempt: attempt + 1)
                    }
                } else {
                    log("❌ Failed to restore cursor position after \(maxAttempts) attempts", level: .error)
                    // Clean up even if we failed
                    previousFocusedElement = nil
                    previousSelectedTextRange = nil
                    originalCursorLocation = 0
                }
            }
        } else {
            log("❌ Could not create AXValue for cursor position", level: .error)
            // Clean up
            previousFocusedElement = nil
            previousSelectedTextRange = nil
            originalCursorLocation = 0
        }
    }
    
    /// Restore focus to the previously active application
    static func restorePreviousAppFocus() {
        guard let previousApp = previousActiveApp else {
            log("⚠️ No previous app to restore focus to", level: .warning)
            return
        }
        
        log("🔄 RESTORING focus to: \(previousApp.localizedName ?? "Unknown") [\(previousApp.bundleIdentifier ?? "no-bundle-id")]", level: .info)
        
        DispatchQueue.main.async {
            // Log current state before hiding
            log("Pre-hide state - Our app active: \(NSApp.isActive)", level: .debug)
            
            // Hide our app first
            NSApp.hide(nil)
            log("📱 Hidden our app", level: .debug)
            
            // Small delay to ensure our window is hidden
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                log("🎯 Attempting to activate: \(previousApp.localizedName ?? "Unknown")", level: .debug)
                
                // Strategy 1: Basic activation
                let success1 = previousApp.activate(options: [.activateIgnoringOtherApps])
                log("Activation attempt 1 result: \(success1)", level: .debug)
                
                // Strategy 2: Force activation with all windows
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    let success2 = previousApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                    log("Activation attempt 2 result: \(success2)", level: .debug)
                    
                    // Strategy 3: Use NSWorkspace launchApplication
                    if !success2 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            if let bundleId = previousApp.bundleIdentifier {
                                let success3 = NSWorkspace.shared.launchApplication(withBundleIdentifier: bundleId, options: [.async], additionalEventParamDescriptor: nil, launchIdentifier: nil) != nil
                                log("NSWorkspace launch attempt result: \(success3)", level: .debug)
                            }
                        }
                    }
                }
                
                // Verify activation after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    verifyFocusRestoration(expectedApp: previousApp)
                    previousActiveApp = nil
                    
                    // Note: cursor position restoration is now handled separately in ContentView after paste
                }
            }
        }
    }
    
    /// Verify that focus was properly restored
    private static func verifyFocusRestoration(expectedApp: NSRunningApplication) {
        log("🔍 VERIFYING focus restoration...", level: .debug)
        
        if let currentFrontmost = NSWorkspace.shared.frontmostApplication {
            if currentFrontmost.bundleIdentifier == expectedApp.bundleIdentifier {
                log("✅ Focus successfully restored to: \(currentFrontmost.localizedName ?? "Unknown")", level: .info)
            } else {
                log("❌ Focus restoration failed! Expected: \(expectedApp.localizedName ?? "Unknown"), Got: \(currentFrontmost.localizedName ?? "Unknown")", level: .error)
            }
        } else {
            log("❌ No frontmost application found after restoration attempt", level: .error)
        }
        
        // Log current focused element
        logFocusedElement()
    }
    
    private static func performPasteOperation(item: ClipboardItem) {
        guard !isOperationInProgress else {
            log("⚠️ Paste operation already in progress, skipping", level: .warning)
            return
        }
        
        isOperationInProgress = true
        defer { isOperationInProgress = false }
        
        log("🎬 STARTING paste operation sequence", level: .info)
        
        // Save current clipboard state
        let previousContent = getCurrentClipboardContent()
        log("💾 Saved previous clipboard content: \(previousContent.text?.prefix(30) ?? "non-text")", level: .debug)
        
        // Set the item content to clipboard
        setClipboardContent(item: item)
        log("📋 Set new content to clipboard", level: .debug)
        
        // Small delay to ensure clipboard is updated
        Thread.sleep(forTimeInterval: 0.15)
        log("⏱️ Clipboard update delay completed", level: .debug)
        
        // Log system state before focus restoration
        log("--- PRE-FOCUS-RESTORATION STATE ---", level: .debug)
        logSystemState()
        
        // First, restore focus to the target application before pasting
        DispatchQueue.main.sync {
            restorePreviousAppFocus()
        }
        
        // Wait for focus to be restored
        Thread.sleep(forTimeInterval: 0.4)  // Increased delay for better focus restoration
        log("⏱️ Focus restoration delay completed", level: .debug)
        
        // Log system state after focus restoration
        log("--- POST-FOCUS-RESTORATION STATE ---", level: .debug)
        logSystemState()
        
        // Perform the paste operation
        log("📝 EXECUTING paste command...", level: .info)
        let pasteSuccess = performActualPaste()
        log("✅ Paste operation completed: \(pasteSuccess)", level: .info)
        
        // Restore previous clipboard content after a delay
        Thread.sleep(forTimeInterval: 0.5)
        restoreClipboardContent(previousContent)
        log("🔄 Previous clipboard content restored", level: .debug)
        
        log("🏁 COMPLETED paste operation sequence", level: .info)
    }
    
    /// Simple paste function for backward compatibility
    static func paste() {
        log("📝 Starting simple paste operation", level: .info)
        operationQueue.async {
            let result = performActualPaste()
            log("Simple paste result: \(result)", level: .info)
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
            log("📋 Current clipboard: Image content", level: .debug)
            return ClipboardContent(text: nil, image: image, data: nil, type: .tiff)
        } else if let string = pasteboard.string(forType: .string) {
            log("📋 Current clipboard: Text content (\(string.count) chars)", level: .debug)
            return ClipboardContent(text: string, image: nil, data: nil, type: .string)
        } else if let data = pasteboard.data(forType: .tiff) {
            log("📋 Current clipboard: Raw data content", level: .debug)
            return ClipboardContent(text: nil, image: nil, data: data, type: .tiff)
        } else {
            log("📋 Current clipboard: Empty or unknown content", level: .debug)
            return ClipboardContent(text: "", image: nil, data: nil, type: .string)
        }
    }
    
    private static func setClipboardContent(item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        
        log("📋 Clearing clipboard...", level: .debug)
        pasteboard.clearContents()
        
        // Small delay to ensure clear is processed
        Thread.sleep(forTimeInterval: 0.05)
        
        if let imageData = item.imageData, let image = NSImage(data: imageData) {
            // Handle image content
            log("📸 Setting image content to clipboard", level: .debug)
            let success = pasteboard.writeObjects([image])
            log("📸 Image write success: \(success)", level: .debug)
        } else if let content = item.content {
            // Handle text content
            log("📝 Setting text content to clipboard: \(content.prefix(50))...", level: .debug)
            let success = pasteboard.setString(content, forType: .string)
            log("📝 Text write success: \(success)", level: .debug)
        } else {
            log("⚠️ No content to set in clipboard", level: .warning)
        }
    }
    private static func restoreClipboardContent(_ content: ClipboardContent) {
        let pasteboard = NSPasteboard.general
        
        log("🔄 Restoring previous clipboard content...", level: .debug)
        pasteboard.clearContents()
        
        // Small delay to ensure clear is processed
        Thread.sleep(forTimeInterval: 0.05)
        
        if let image = content.image {
            let success = pasteboard.writeObjects([image])
            log("🔄 Restored image content: \(success)", level: .debug)
        } else if let text = content.text {
            let success = pasteboard.setString(text, forType: .string)
            log("🔄 Restored text content: \(success) - \(text.prefix(30))...", level: .debug)
        } else if let data = content.data, let type = content.type {
            pasteboard.setData(data, forType: type)
            log("🔄 Restored data content of type: \(type)", level: .debug)
        }
    }
    
    // MARK: - Reliable Paste Implementation
    
    private static func performActualPaste() -> Bool {
        log("🎯 EXECUTING paste operation", level: .info)
        
        // Log current focused element before paste
        log("Pre-paste focused element:", level: .debug)
        logFocusedElement()
        
        // First try AppleScript approach (most reliable)
        if performAppleScriptPaste() {
            log("✅ AppleScript paste succeeded", level: .info)
            return true
        }
        
        // Fallback to CGEvent approach
        log("⚡ Falling back to CGEvent paste", level: .warning)
        return performCGEventPaste()
    }
    
    private static func performAppleScriptPaste() -> Bool {
        log("📜 Attempting AppleScript paste...", level: .debug)
        
        let script = """
        tell application "System Events"
            key code 9 using command down
        end tell
        """
        
        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        let result = appleScript?.executeAndReturnError(&error)
        
        if let error = error {
            log("❌ AppleScript error: \(error)", level: .error)
            return false
        }
        
        log("✅ AppleScript executed successfully", level: .debug)
        return result != nil
    }
    
    private static func performCGEventPaste() -> Bool {
        log("🔑 Performing CGEvent paste", level: .debug)
        
        // Create event source
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            log("❌ Failed to create event source", level: .error)
            return false
        }
        
        // Get the V key code (works for all keyboard layouts)
        let vKeyCode: CGKeyCode = 9
        
        // Create key down and up events for CMD+V
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            log("❌ Failed to create key events", level: .error)
            return false
        }
        
        // Set command modifier
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        
        // Post the events
        keyDown.post(tap: .cgSessionEventTap)
        Thread.sleep(forTimeInterval: 0.05)  // Small delay between key down and up
        keyUp.post(tap: .cgSessionEventTap)
        
        log("✅ CGEvent paste completed", level: .debug)
        return true
    }
}

// MARK: - DateFormatter Extension for Debug Logging

extension DateFormatter {
    static let debugFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}
