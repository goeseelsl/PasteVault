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
        // Local monitor for navigation keys when app is in focus
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            switch Int(event.keyCode) {
            case KeyCode.downArrow:
                self.keyPressed = ("down", true)
                return nil // Consume the event
            case KeyCode.upArrow:
                self.keyPressed = ("up", true)
                return nil // Consume the event
            case KeyCode.returnKey:
                self.keyPressed = ("return", true)
                return nil // Consume the event
            case KeyCode.escape:
                self.keyPressed = ("escape", true)
                return nil // Consume the event
            default:
                return event // Let other keys pass through
            }
        }
        
        // Remove global monitor - too intrusive
        // We'll rely on the local monitor and proper window focus
    }
    
    /// Stop monitoring keyboard events
    func stopMonitoring() {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }
    
    deinit {
        stopMonitoring()
    }
}
