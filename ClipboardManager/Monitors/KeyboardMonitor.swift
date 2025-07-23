import Foundation
import AppKit

// MARK: - Constants
private enum KeyCode {
    static let downArrow = 125
    static let upArrow = 126
    static let returnKey = 36
    static let escape = 53
}

/// Monitors keyboard events for navigation within the clipboard manager
class KeyboardMonitor: ObservableObject {
    private var localEventMonitor: Any?
    @Published var keyPressed: (String, Bool)? // (keyCode, isPressed)
    
    /// Start monitoring keyboard events
    func startMonitoring() {
        PasteHelper.log("🔧 KeyboardMonitor starting local event monitoring", level: .info)
        
        // Local monitor for navigation keys when app is in focus
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            let keyCode = Int(event.keyCode)
            
            switch keyCode {
            case KeyCode.downArrow:
                PasteHelper.log("⬇️ Down arrow key detected", level: .debug)
                self.keyPressed = ("down", true)
                return nil // Consume the event
            case KeyCode.upArrow:
                PasteHelper.log("⬆️ Up arrow key detected", level: .debug)
                self.keyPressed = ("up", true)
                return nil // Consume the event
            case KeyCode.returnKey:
                PasteHelper.log("⏎ ENTER key detected - triggering paste!", level: .info)
                self.keyPressed = ("return", true)
                return nil // Consume the event
            case KeyCode.escape:
                PasteHelper.log("⎋ Escape key detected", level: .debug)
                self.keyPressed = ("escape", true)
                return nil // Consume the event
            default:
                // Log other keys for debugging
                PasteHelper.log("⌨️ Other key pressed: \(keyCode)", level: .debug)
                return event // Let other keys pass through
            }
        }
        
        // Remove global monitor - too intrusive
        // We'll rely on the local monitor and proper window focus
        
        PasteHelper.log("✅ KeyboardMonitor successfully started", level: .info)
    }
    
    /// Stop monitoring keyboard events
    func stopMonitoring() {
        PasteHelper.log("🛑 KeyboardMonitor stopping event monitoring", level: .info)
        
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
            PasteHelper.log("✅ KeyboardMonitor successfully stopped", level: .info)
        }
    }
    
    deinit {
        stopMonitoring()
    }
}
