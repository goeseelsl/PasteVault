import Foundation
import Carbon

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

    init() {
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        InstallEventHandler(GetApplicationEventTarget(), hotkeyHandler, 1, &eventType, nil, nil)
    }

    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = FourCharCode(string: "htk1")
        hotKeyID.id = UInt32(hotkeys.count + disabledHotkeys.count + 1)

        let id = "\(hotKeyID.signature)-\(hotKeyID.id)"
        hotkeyHandlers[id] = handler

        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status == noErr {
            if isTemporarilyDisabled {
                disabledHotkeys[id] = hotKeyRef
            } else {
                hotkeys[id] = hotKeyRef
            }
        }
    }

    func unregisterAll() {
        for (_, hotKeyRef) in hotkeys {
            UnregisterEventHotKey(hotKeyRef)
        }
        for (_, hotKeyRef) in disabledHotkeys {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotkeys.removeAll()
        disabledHotkeys.removeAll()
    }
    
    func temporarilyDisable() {
        guard !isTemporarilyDisabled else { return }
        isTemporarilyDisabled = true
        
        // Move active hotkeys to disabled state
        for (id, hotKeyRef) in hotkeys {
            UnregisterEventHotKey(hotKeyRef)
            disabledHotkeys[id] = hotKeyRef
        }
        hotkeys.removeAll()
    }
    
    func reenable() {
        guard isTemporarilyDisabled else { return }
        isTemporarilyDisabled = false
        
        // Re-register disabled hotkeys
        for (id, _) in disabledHotkeys {
            if hotkeyHandlers[id] != nil {
                // Extract the original key info and re-register
                // For now, we'll just clear and let the system re-register
                // This is a simplified approach
            }
        }
        
        // Clear disabled hotkeys - the system will re-register them
        for (_, hotKeyRef) in disabledHotkeys {
            UnregisterEventHotKey(hotKeyRef)
        }
        disabledHotkeys.removeAll()
        
        // Trigger hotkey reload
        NotificationCenter.default.post(name: .reloadHotkeys, object: nil, userInfo: nil)
    }
}

extension FourCharCode {
    init(string: String) {
        self = string.utf16.reduce(0, {$0 << 8 + FourCharCode($1)})
    }
}