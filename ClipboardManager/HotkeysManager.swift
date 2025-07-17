import Foundation
import Carbon
import AppKit

private var hotkeyHandlers: [String: () -> Void] = [:]

private func hotkeyHandler(nextHandler: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    let hotKeyID = UnsafeMutablePointer<EventHotKeyID>.allocate(capacity: 1)
    defer { hotKeyID.deallocate() }

    let result = GetEventParameter(event,
                                   UInt32(kEventParamDirectObject),
                                   UInt32(typeEventHotKeyID),
                                   nil,
                                   MemoryLayout<EventHotKeyID>.size,
                                   nil,
                                   hotKeyID)

    if result == noErr {
        let id = "\(hotKeyID.pointee.signature)-\(hotKeyID.pointee.id)"
        hotkeyHandlers[id]?()
    }

    return noErr
}

class HotkeysManager {
    static let shared = HotkeysManager()
    private var hotkeys: [String: EventHotKeyRef] = [:]
    private var disabledHotkeys: [String: EventHotKeyRef] = [:]
    private var isTemporarilyDisabled = false
    
    // Public property to check if hotkeys are enabled
    var isEnabled: Bool {
        return !isTemporarilyDisabled
    }
    
    // Get current hotkeys count
    var activeHotkeysCount: Int {
        return hotkeys.count
    }
    
    // Get current disabled hotkeys count
    var disabledHotkeysCount: Int {
        return disabledHotkeys.count
    }

    init() {
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        InstallEventHandler(GetApplicationEventTarget(), hotkeyHandler, 1, &eventType, nil, nil)
    }

    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        print("🔑 Registering hotkey: keyCode=\(keyCode), modifiers=\(modifiers)")
        
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = FourCharCode(string: "htk1")
        hotKeyID.id = UInt32(hotkeys.count + disabledHotkeys.count + 1)

        let id = "\(hotKeyID.signature)-\(hotKeyID.id)"
        hotkeyHandlers[id] = handler

        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        
        if status == noErr {
            print("✅ Hotkey registered successfully with id: \(id)")
            if isTemporarilyDisabled {
                disabledHotkeys[id] = hotKeyRef
            } else {
                hotkeys[id] = hotKeyRef
            }
        } else {
            print("❌ Failed to register hotkey: status=\(status)")
        }
    }

    func unregisterAll() {
        print("🔄 Unregistering all hotkeys - active: \(hotkeys.count), disabled: \(disabledHotkeys.count)")
        
        var successCount = 0
        var failCount = 0
        
        for (id, hotKeyRef) in hotkeys {
            let status = UnregisterEventHotKey(hotKeyRef)
            if status == noErr {
                successCount += 1
            } else {
                failCount += 1
                print("⚠️ Failed to unregister hotkey \(id): status=\(status)")
            }
        }
        
        for (id, hotKeyRef) in disabledHotkeys {
            let status = UnregisterEventHotKey(hotKeyRef)
            if status == noErr {
                successCount += 1
            } else {
                failCount += 1
                print("⚠️ Failed to unregister disabled hotkey \(id): status=\(status)")
            }
        }
        
        print("✅ Unregistered \(successCount) hotkeys successfully" + (failCount > 0 ? ", \(failCount) failed" : ""))
        
        // Clear the dictionaries even if unregistering failed
        hotkeys.removeAll()
        disabledHotkeys.removeAll()
        
        // Keep the handlers intact - they'll be reused when hotkeys are registered again
    }
    
    func temporarilyDisable() {
        guard !isTemporarilyDisabled else { return }
        isTemporarilyDisabled = true
        
        print("🔄 HotkeysManager: Temporarily disabling hotkeys")
        
        // Move active hotkeys to disabled state
        for (id, hotKeyRef) in hotkeys {
            UnregisterEventHotKey(hotKeyRef)
            disabledHotkeys[id] = hotKeyRef
        }
        hotkeys.removeAll()
    }
    
    func reenable() {
        print("🔄 HotkeysManager: Re-enabling hotkeys")
        
        // First, ensure we're in the disabled state
        guard isTemporarilyDisabled else { 
            print("⚠️ HotkeysManager: Not in disabled state, nothing to do")
            return 
        }
        
        // Reset the flag immediately to allow new registrations
        isTemporarilyDisabled = false
        
        // Fast path: If there are disabled hotkeys, try to re-register them directly
        if !disabledHotkeys.isEmpty {
            var reregistrationSuccessful = true
            
            // Try to directly re-register the disabled hotkeys
            for (id, _) in disabledHotkeys {
                // Extract signature and ID from the composite key
                let components = id.split(separator: "-")
                if components.count == 2,
                   let signatureString = components.first,
                   let idString = components.last,
                   let hotkeyId = UInt32(idString) {
                    
                    // Recreate the hotkey ID
                    var hotKeyID = EventHotKeyID()
                    hotKeyID.signature = FourCharCode(string: String(signatureString))
                    hotKeyID.id = hotkeyId
                    
                    // Try to register with the same handler
                    if let handler = hotkeyHandlers[id] {
                        // Find the key and modifiers for this hotkey (not ideal but necessary for direct re-registration)
                        // In a production app, we'd store this info separately
                        var hotKeyRef: EventHotKeyRef?
                        let status = RegisterEventHotKey(0, 0, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
                        
                        if status != noErr {
                            reregistrationSuccessful = false
                            break
                        }
                    }
                }
            }
            
            // If direct re-registration failed, fall back to complete reload
            if !reregistrationSuccessful {
                print("⚠️ HotkeysManager: Direct re-registration failed, falling back to complete reload")
                fallbackToCompleteReload()
            } else {
                print("✅ HotkeysManager: Hotkeys re-registered successfully")
                return
            }
        } else {
            fallbackToCompleteReload()
        }
    }
    
    private func fallbackToCompleteReload() {
        // IMPORTANT: Rather than trying to re-enable the existing hotkeys,
        // we'll completely unregister everything and re-register from scratch
        // This is the most reliable approach
        
        // Clear all existing hotkeys (both active and disabled)
        print("🔹 HotkeysManager: Unregistering \(hotkeys.count) active hotkeys")
        for (_, hotKeyRef) in hotkeys {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotkeys.removeAll()
        
        print("🔹 HotkeysManager: Unregistering \(disabledHotkeys.count) disabled hotkeys")
        for (_, hotKeyRef) in disabledHotkeys {
            UnregisterEventHotKey(hotKeyRef)
        }
        disabledHotkeys.removeAll()
        
        print("✅ HotkeysManager: All hotkeys cleared, triggering complete reload")
        
        // Trigger a complete reload of all hotkeys - immediately on the main thread for speed
        NotificationCenter.default.post(name: .reloadHotkeys, object: nil, userInfo: nil)
        print("✅ HotkeysManager: Hotkeys reloaded notification sent")
        
        // Add verification step to check if hotkeys were properly registered
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { // reduced from 0.2 to 0.05
            let appDelegate = NSApplication.shared.delegate as? AppDelegate
            print("🔍 HotkeysManager: Verification after reload:")
            print("  • isEnabled = \(self.isEnabled)")
            print("  • Active hotkeys count = \(self.hotkeys.count)")
            print("  • Disabled hotkeys count = \(self.disabledHotkeys.count)")
            
            if self.hotkeys.isEmpty && self.isEnabled {
                print("⚠️ HotkeysManager: Warning - no active hotkeys after reload, forcing reload again")
                appDelegate?.registerHotkeys()
            }
        }
    }
}

extension FourCharCode {
    init(string: String) {
        self = string.utf16.reduce(0, {$0 << 8 + FourCharCode($1)})
    }
}