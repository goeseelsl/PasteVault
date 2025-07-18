import Foundation
import SwiftUI
import AppKit

// MARK: - Notification Names
extension NSNotification.Name {
    static let pasteOperationStart = NSNotification.Name("pasteOperationStart")
    static let pasteOperationEnd = NSNotification.Name("pasteOperationEnd")
    static let showClipboardHistory = NSNotification.Name("showClipboardHistory")
    static let showSearch = NSNotification.Name("showSearch")
    static let toggleSidebar = NSNotification.Name("toggleSidebar")
    static let pasteItemAtIndex = NSNotification.Name("pasteItemAtIndex")
}

/// Custom actions and automation system
class CustomActionsManager: ObservableObject {
    @Published var customActions: [CustomAction] = []
    @Published var isExecuting = false
    
    init() {
        loadDefaultActions()
    }
    
    /// Execute a custom action on clipboard item
    func executeAction(_ action: CustomAction, on item: ClipboardItem) {
        guard let content = item.content else { return }
        
        isExecuting = true
        
        switch action.type {
        case .appleScript:
            executeAppleScript(action.script, with: content) { result in
                DispatchQueue.main.async {
                    if let result = result {
                        item.content = result
                        self.saveContext(item)
                    }
                    self.isExecuting = false
                }
            }
        case .textTransform:
            let result = executeTextTransform(action.transformType, on: content)
            item.content = result
            saveContext(item)
            isExecuting = false
        case .shortcut:
            executeShortcut(action.shortcutName, with: content)
            isExecuting = false
        }
    }
    
    /// Add a new custom action
    func addAction(_ action: CustomAction) {
        customActions.append(action)
        saveActions()
    }
    
    /// Remove a custom action
    func removeAction(_ action: CustomAction) {
        customActions.removeAll { $0.id == action.id }
        saveActions()
    }
    
    private func loadDefaultActions() {
        customActions = [
            CustomAction(
                name: "Uppercase",
                description: "Convert text to uppercase",
                type: .textTransform,
                transformType: .uppercase,
                icon: "textformat.abc"
            ),
            CustomAction(
                name: "Lowercase",
                description: "Convert text to lowercase",
                type: .textTransform,
                transformType: .lowercase,
                icon: "textformat.abc"
            ),
            CustomAction(
                name: "Title Case",
                description: "Convert text to title case",
                type: .textTransform,
                transformType: .titleCase,
                icon: "textformat.abc"
            ),
            CustomAction(
                name: "Remove Formatting",
                description: "Strip all formatting",
                type: .textTransform,
                transformType: .stripFormatting,
                icon: "textformat.alt"
            ),
            CustomAction(
                name: "Extract URLs",
                description: "Extract all URLs from text",
                type: .textTransform,
                transformType: .extractURLs,
                icon: "link"
            ),
            CustomAction(
                name: "Word Count",
                description: "Count words in text",
                type: .textTransform,
                transformType: .wordCount,
                icon: "number"
            )
        ]
    }
    
    private func executeAppleScript(_ script: String, with content: String, completion: @escaping (String?) -> Void) {
        let fullScript = script.replacingOccurrences(of: "{{content}}", with: content)
        
        DispatchQueue.global(qos: .userInitiated).async {
            let appleScript = NSAppleScript(source: fullScript)
            var error: NSDictionary?
            
            if let output = appleScript?.executeAndReturnError(&error) {
                completion(output.stringValue)
            } else {
                print("AppleScript error: \(error ?? [:])")
                completion(nil)
            }
        }
    }
    
    private func executeTextTransform(_ transform: TextTransform, on content: String) -> String {
        switch transform {
        case .uppercase:
            return content.uppercased()
        case .lowercase:
            return content.lowercased()
        case .titleCase:
            return content.capitalized
        case .stripFormatting:
            return content
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        case .extractURLs:
            return extractURLs(from: content)
        case .wordCount:
            let words = content.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            return "Word count: \(words.count)"
        case .reverseText:
            return String(content.reversed())
        case .base64Encode:
            return content.data(using: .utf8)?.base64EncodedString() ?? content
        case .base64Decode:
            guard let data = Data(base64Encoded: content) else { return content }
            return String(data: data, encoding: .utf8) ?? content
        }
    }
    
    private func executeShortcut(_ shortcutName: String, with content: String) {
        let url = URL(string: "shortcuts://run-shortcut?name=\(shortcutName)&input=\(content.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
        NSWorkspace.shared.open(url)
    }
    
    private func extractURLs(from text: String) -> String {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        let urls = matches?.compactMap { match in
            return match.url?.absoluteString
        } ?? []
        
        return urls.joined(separator: "\n")
    }
    
    private func saveActions() {
        // Save to UserDefaults or plist
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(customActions) {
            UserDefaults.standard.set(data, forKey: "CustomActions")
        }
    }
    
    private func saveContext(_ item: ClipboardItem) {
        // This would need access to the managed object context
        // For now, we'll assume the context is saved elsewhere
    }
}

/// Custom action model
struct CustomAction: Identifiable, Codable {
    let id = UUID()
    let name: String
    let description: String
    let type: ActionType
    let script: String
    let transformType: TextTransform
    let shortcutName: String
    let icon: String
    
    init(name: String, description: String, type: ActionType, script: String = "", transformType: TextTransform = .uppercase, shortcutName: String = "", icon: String = "gear") {
        self.name = name
        self.description = description
        self.type = type
        self.script = script
        self.transformType = transformType
        self.shortcutName = shortcutName
        self.icon = icon
    }
    
    enum ActionType: String, Codable, CaseIterable {
        case appleScript = "AppleScript"
        case textTransform = "Text Transform"
        case shortcut = "Shortcut"
        
        var icon: String {
            switch self {
            case .appleScript: return "applescript"
            case .textTransform: return "textformat"
            case .shortcut: return "shortcuts"
            }
        }
    }
}

/// Text transformation types
enum TextTransform: String, Codable, CaseIterable {
    case uppercase = "Uppercase"
    case lowercase = "Lowercase"
    case titleCase = "Title Case"
    case stripFormatting = "Strip Formatting"
    case extractURLs = "Extract URLs"
    case wordCount = "Word Count"
    case reverseText = "Reverse Text"
    case base64Encode = "Base64 Encode"
    case base64Decode = "Base64 Decode"
}

/// Global shortcuts manager
class GlobalShortcutsManager: ObservableObject {
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private var isTemporarilyDisabled = false
    
    init() {
        setupGlobalShortcuts()
        
        // Listen for paste operations that might disrupt event handling
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePasteOperationStart),
            name: .pasteOperationStart,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePasteOperationEnd),
            name: .pasteOperationEnd,
            object: nil
        )
    }
    
    @objc private func handlePasteOperationStart() {
        print("🔄 Temporarily disabling shortcuts for paste operation")
        isTemporarilyDisabled = true
    }
    
    @objc private func handlePasteOperationEnd() {
        print("🔄 Re-enabling shortcuts after paste operation")
        
        // Add a longer delay to ensure paste operation is fully complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isTemporarilyDisabled = false
            
            // Reinitialize event monitors to ensure they're working properly
            self.reinitializeEventMonitors()
        }
    }
    
    private func reinitializeEventMonitors() {
        print("🔄 Reinitializing event monitors for better reliability")
        
        // Remove existing monitors
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        
        // Small delay to ensure cleanup is complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            // Re-create monitors
            self.setupGlobalShortcuts()
            print("✅ Event monitors reinitialized successfully")
        }
    }
    
    private func setupGlobalShortcuts() {
        print("🔧 Setting up global shortcuts...")
        
        // Global monitor for when app is not in focus
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            self.handleGlobalKeyEvent(event)
        }
        
        // Local monitor for when app is in focus
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            self.handleGlobalKeyEvent(event)
            return event // Don't consume the event, let it pass through
        }
        
        print("✅ Global shortcuts setup complete - global: \(globalEventMonitor != nil), local: \(localEventMonitor != nil)")
    }
    
    private func handleGlobalKeyEvent(_ event: NSEvent) {
        // Skip if temporarily disabled during paste operations
        if isTemporarilyDisabled {
            print("⏭️ Skipping shortcut handling - disabled during paste operation")
            return
        }
        
        let flags = event.modifierFlags
        let keyCode = event.keyCode
        
        // Don't log ESC key - it should be handled by local keyboard monitor
        if keyCode != 53 {
            print("🔍 Global shortcut detected: keyCode=\(keyCode), flags=\(flags)")
        }
        
        // Skip ESC key handling - let local monitors handle it
        if keyCode == 53 {
            return
        }
        
        // Cmd+Shift+V - Show clipboard history
        if flags.contains([.command, .shift]) && keyCode == 9 { // V key
            print("📋 Triggering clipboard history")
            NotificationCenter.default.post(name: .showClipboardHistory, object: nil)
        }
        
        // Cmd+Shift+F - Show search
        if flags.contains([.command, .shift]) && keyCode == 3 { // F key
            print("🔍 Triggering search")
            NotificationCenter.default.post(name: .showSearch, object: nil)
        }
        
        // Cmd+Shift+B - Toggle sidebar
        if flags.contains([.command, .shift]) && keyCode == 11 { // B key
            print("📁 Triggering sidebar toggle")
            NotificationCenter.default.post(name: .toggleSidebar, object: nil)
        }
        
        // Cmd+Shift+C - Toggle sidebar (alternative)
        if flags.contains([.command, .shift]) && keyCode == 8 { // C key
            print("📁 Triggering sidebar toggle (C key)")
            NotificationCenter.default.post(name: .toggleSidebar, object: nil)
        }
        
        // Cmd+Option+1-9 - Paste specific item
        if flags.contains([.command, .option]) && keyCode >= 18 && keyCode <= 26 {
            let itemIndex = Int(keyCode) - 18 // Convert to 0-based index
            print("📋 Triggering paste item at index \(itemIndex)")
            NotificationCenter.default.post(name: .pasteItemAtIndex, object: itemIndex)
        }
    }
    
    deinit {
        // Remove notification observers
        NotificationCenter.default.removeObserver(self)
        
        // Remove event monitors
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

/// Custom actions view
struct CustomActionsView: View {
    @ObservedObject var actionsManager: CustomActionsManager
    let item: ClipboardItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom Actions")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
            
            if actionsManager.customActions.isEmpty {
                Text("No custom actions available")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } else {
                ForEach(actionsManager.customActions) { action in
                    CustomActionRow(
                        action: action,
                        isExecuting: actionsManager.isExecuting,
                        onExecute: {
                            actionsManager.executeAction(action, on: item)
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

/// Individual custom action row
struct CustomActionRow: View {
    let action: CustomAction
    let isExecuting: Bool
    let onExecute: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: action.icon)
                .font(.system(size: 12))
                .foregroundColor(.accentColor)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(action.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(action.description)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onExecute) {
                if isExecuting {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isExecuting)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(NSColor.windowBackgroundColor))
        )
    }
}
