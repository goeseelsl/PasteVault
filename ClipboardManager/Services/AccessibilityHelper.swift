import Foundation
import AppKit

/// Helper class for managing accessibility permissions
/// Based on Clipy/Maccy implementations for professional accessibility handling
class AccessibilityHelper {
    
    /// Check if accessibility permissions are granted and request them if needed
    /// - Returns: True if accessibility permissions are available
    static func checkAccessibilityPermissions() -> Bool {
        let accessEnabled = AXIsProcessTrusted()
        
        if !accessEnabled {
            print("❌ Accessibility permissions required for paste functionality")
            
            // Prompt for permissions like Maccy does
            let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
            let options = [checkOptPrompt: true]
            let _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        }
        
        return accessEnabled
    }
    
    /// Request accessibility permissions without checking current state
    static func requestAccessibilityPermissions() {
        let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
        let options = [checkOptPrompt: true]
        let _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
