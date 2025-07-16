import Foundation
import AppKit

/// Monitors keyboard events for navigation within the clipboard manager
class KeyboardMonitor: ObservableObject {
    private var eventMonitor: Any?
    @Published var keyPressed: (String, Bool)? // (keyCode, isPressed)
    
    /// Start monitoring keyboard events
    func startMonitoring() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            switch Int(event.keyCode) {
            case 125: // Down arrow
                self.keyPressed = ("down", true)
                return nil // Consume the event
            case 126: // Up arrow
                self.keyPressed = ("up", true)
                return nil // Consume the event
            case 36: // Return/Enter
                self.keyPressed = ("return", true)
                return nil // Consume the event
            case 53: // Escape
                self.keyPressed = ("escape", true)
                return nil // Consume the event
            default:
                return event // Let other keys pass through
            }
        }
    }
    
    /// Stop monitoring keyboard events
    func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    deinit {
        stopMonitoring()
    }
}
