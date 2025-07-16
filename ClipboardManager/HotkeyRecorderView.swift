import SwiftUI
import Carbon

struct HotkeyRecorderView: View {
    @Binding var hotkey: Hotkey
    @State private var isRecording = false
    @State private var recordingFeedback = ""

    var body: some View {
        HStack {
            Text(isRecording ? (recordingFeedback.isEmpty ? "Press keys..." : recordingFeedback) : hotkey.description)
                .padding(8)
                .background(isRecording ? Color.blue.opacity(0.2) : Color.clear)
                .foregroundColor(isRecording ? .blue : .primary)
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isRecording ? Color.blue : Color.gray, lineWidth: isRecording ? 2 : 1)
                )
                .onTapGesture {
                    if !isRecording {
                        startRecording()
                    }
                }
            
            if isRecording {
                Button("Cancel") {
                    cancelRecording()
                }
                .buttonStyle(.bordered)
            }
        }
        .background(KeyEventHandling(isRecording: $isRecording, hotkey: $hotkey, recordingFeedback: $recordingFeedback))
    }
    
    private func startRecording() {
        isRecording = true
        recordingFeedback = ""
        // Notify the system to temporarily disable global hotkeys
        NotificationCenter.default.post(name: .disableGlobalHotkeys, object: nil)
    }
    
    private func cancelRecording() {
        isRecording = false
        recordingFeedback = ""
        // Re-enable global hotkeys
        NotificationCenter.default.post(name: .enableGlobalHotkeys, object: nil)
    }
}

struct Hotkey: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    var description: String {
        let keyString = keyCodeToString(keyCode)
        let modifierString = modifierFlagsToString(modifiers)
        return "\(modifierString)\(keyString.uppercased())"
    }
    
    private func keyCodeToString(_ keyCode: UInt32) -> String {
        // Common key codes mapping
        switch keyCode {
        case UInt32(kVK_ANSI_A): return "A"
        case UInt32(kVK_ANSI_B): return "B"
        case UInt32(kVK_ANSI_C): return "C"
        case UInt32(kVK_ANSI_D): return "D"
        case UInt32(kVK_ANSI_E): return "E"
        case UInt32(kVK_ANSI_F): return "F"
        case UInt32(kVK_ANSI_G): return "G"
        case UInt32(kVK_ANSI_H): return "H"
        case UInt32(kVK_ANSI_I): return "I"
        case UInt32(kVK_ANSI_J): return "J"
        case UInt32(kVK_ANSI_K): return "K"
        case UInt32(kVK_ANSI_L): return "L"
        case UInt32(kVK_ANSI_M): return "M"
        case UInt32(kVK_ANSI_N): return "N"
        case UInt32(kVK_ANSI_O): return "O"
        case UInt32(kVK_ANSI_P): return "P"
        case UInt32(kVK_ANSI_Q): return "Q"
        case UInt32(kVK_ANSI_R): return "R"
        case UInt32(kVK_ANSI_S): return "S"
        case UInt32(kVK_ANSI_T): return "T"
        case UInt32(kVK_ANSI_U): return "U"
        case UInt32(kVK_ANSI_V): return "V"
        case UInt32(kVK_ANSI_W): return "W"
        case UInt32(kVK_ANSI_X): return "X"
        case UInt32(kVK_ANSI_Y): return "Y"
        case UInt32(kVK_ANSI_Z): return "Z"
        case UInt32(kVK_ANSI_0): return "0"
        case UInt32(kVK_ANSI_1): return "1"
        case UInt32(kVK_ANSI_2): return "2"
        case UInt32(kVK_ANSI_3): return "3"
        case UInt32(kVK_ANSI_4): return "4"
        case UInt32(kVK_ANSI_5): return "5"
        case UInt32(kVK_ANSI_6): return "6"
        case UInt32(kVK_ANSI_7): return "7"
        case UInt32(kVK_ANSI_8): return "8"
        case UInt32(kVK_ANSI_9): return "9"
        case UInt32(kVK_Space): return "Space"
        case UInt32(kVK_Return): return "Return"
        case UInt32(kVK_Tab): return "Tab"
        case UInt32(kVK_Delete): return "Delete"
        case UInt32(kVK_Escape): return "Escape"
        case UInt32(kVK_F1): return "F1"
        case UInt32(kVK_F2): return "F2"
        case UInt32(kVK_F3): return "F3"
        case UInt32(kVK_F4): return "F4"
        case UInt32(kVK_F5): return "F5"
        case UInt32(kVK_F6): return "F6"
        case UInt32(kVK_F7): return "F7"
        case UInt32(kVK_F8): return "F8"
        case UInt32(kVK_F9): return "F9"
        case UInt32(kVK_F10): return "F10"
        case UInt32(kVK_F11): return "F11"
        case UInt32(kVK_F12): return "F12"
        case UInt32(kVK_LeftArrow): return "←"
        case UInt32(kVK_RightArrow): return "→"
        case UInt32(kVK_UpArrow): return "↑"
        case UInt32(kVK_DownArrow): return "↓"
        default:
            // Try to use the keyboard layout for other keys
            return keyCodeToStringWithLayout(keyCode) ?? "Key \(keyCode)"
        }
    }
    
    private func keyCodeToStringWithLayout(_ keyCode: UInt32) -> String? {
        guard let inputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let layoutDataPtr = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        
        let layoutData = layoutDataPtr.assumingMemoryBound(to: CFData.self).pointee
        let keyboardLayout = unsafeBitCast(CFDataGetBytePtr(layoutData), to: UnsafePointer<UCKeyboardLayout>.self)
        
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var realLength = 0
        
        let result = UCKeyTranslate(keyboardLayout,
                                    UInt16(keyCode),
                                    UInt16(kUCKeyActionDisplay),
                                    0,
                                    UInt32(LMGetKbdType()),
                                    UInt32(kUCKeyTranslateNoDeadKeysBit),
                                    &deadKeyState,
                                    4,
                                    &realLength,
                                    &chars)
        
        if result == noErr && realLength > 0 {
            return String(utf16CodeUnits: chars, count: realLength)
        }
        
        return nil
    }
}

struct KeyEventHandling: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var hotkey: Hotkey
    @Binding var recordingFeedback: String

    func makeNSView(context: Context) -> KeyEventView {
        let view = KeyEventView()
        view.isRecording = isRecording
        view.onKeyRecorded = { newHotkey in
            hotkey = newHotkey
        }
        view.onRecordingFeedback = { feedback in
            recordingFeedback = feedback
        }
        view.onRecordingComplete = {
            isRecording = false
            recordingFeedback = ""
            // Re-enable global hotkeys
            NotificationCenter.default.post(name: .enableGlobalHotkeys, object: nil)
        }
        return view
    }

    func updateNSView(_ nsView: KeyEventView, context: Context) {
        nsView.isRecording = isRecording
        if !isRecording {
            nsView.stopRecording()
        }
    }
}

class KeyEventView: NSView {
    var isRecording = false {
        didSet {
            if isRecording {
                startRecording()
            } else {
                stopRecording()
            }
        }
    }
    var onKeyRecorded: ((Hotkey) -> Void)?
    var onRecordingFeedback: ((String) -> Void)?
    var onRecordingComplete: (() -> Void)?
    private var eventMonitor: Any?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func startRecording() {
        stopRecording() // Stop any existing monitoring
        
        // Use global event monitor to capture all key events, even those that would be handled by global hotkeys
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self = self, self.isRecording else { return }
            
            if event.type == .keyDown {
                // Check if this is a valid key combination (has modifiers)
                let modifierFlags = event.modifierFlags.carbonFlags
                
                // Only accept combinations with at least one modifier key
                if modifierFlags != 0 {
                    let newHotkey = Hotkey(keyCode: UInt32(event.keyCode), modifiers: modifierFlags)
                    
                    // Provide immediate feedback
                    self.onRecordingFeedback?(newHotkey.description)
                    
                    // Small delay to show the feedback, then complete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.onKeyRecorded?(newHotkey)
                        self.onRecordingComplete?()
                    }
                } else {
                    // Show feedback for invalid combinations
                    self.onRecordingFeedback?("Press modifier keys (⌘, ⌥, ⌃, ⇧) + key")
                }
            } else if event.type == .flagsChanged {
                // Show current modifiers being pressed
                let modifierFlags = event.modifierFlags.carbonFlags
                if modifierFlags != 0 {
                    let modifierString = modifierFlagsToString(modifierFlags)
                    self.onRecordingFeedback?("\(modifierString)...")
                } else {
                    self.onRecordingFeedback?("Press modifier keys + key")
                }
            }
        }
    }
    
    func stopRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    deinit {
        stopRecording()
    }
}

extension NSEvent.ModifierFlags {
    var carbonFlags: UInt32 {
        var flags: UInt32 = 0
        if contains(.command) { flags |= UInt32(cmdKey) }
        if contains(.option) { flags |= UInt32(optionKey) }
        if contains(.control) { flags |= UInt32(controlKey) }
        if contains(.shift) { flags |= UInt32(shiftKey) }
        return flags
    }
}

func modifierFlagsToString(_ flags: UInt32) -> String {
    var result = ""
    if flags & UInt32(cmdKey) != 0 { result += "⌘" }
    if flags & UInt32(optionKey) != 0 { result += "⌥" }
    if flags & UInt32(controlKey) != 0 { result += "⌃" }
    if flags & UInt32(shiftKey) != 0 { result += "⇧" }
    return result
}
