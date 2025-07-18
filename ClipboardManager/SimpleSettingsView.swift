import SwiftUI
import Carbon
import UniformTypeIdentifiers
import Foundation

// MARK: - Simple Settings View (Memory Safe)
struct SimpleSettingsView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Beautiful header
            HStack {
                Image(systemName: "clipboard.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("ClipboardManager")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Advanced clipboard management")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("v1.0.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding()
            .background(Color.primary.opacity(0.03))
            
            // TabView
            TabView(selection: $selectedTab) {
                SimpleGeneralSettingsView()
                    .tabItem {
                        Label("General", systemImage: "gear")
                    }
                    .tag(0)
                
                SimpleEnhancedShortcutsView()
                    .tabItem {
                        Label("Keyboard", systemImage: "keyboard")
                    }
                    .tag(1)
                
                SimpleAppearanceSettingsView()
                    .tabItem {
                        Label("Appearance", systemImage: "paintbrush")
                    }
                    .tag(2)
                
                CloudKitSyncSettingsView()
                    .tabItem {
                        Label("Sync", systemImage: "icloud")
                    }
                    .tag(3)
                
                SimpleAdvancedSettingsView()
                    .tabItem {
                        Label("Advanced", systemImage: "slider.horizontal.3")
                    }
                    .tag(4)
            }
        }
        .frame(width: 650, height: 550)
    }
}

struct SimpleGeneralSettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("maxHistorySize") private var maxHistorySize = 100
    @ObservedObject private var syncManager = CloudKitSyncManager.shared
    @State private var showingEnableAlert = false
    @State private var showingDisableAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SettingsSection(title: "Startup", icon: "power", color: .green) {
                    VStack(spacing: 12) {
                        SettingsRow(
                            title: "Launch at Login",
                            description: "Automatically start ClipboardManager when you log in",
                            icon: "power"
                        ) {
                            Toggle("", isOn: $launchAtLogin)
                                .toggleStyle(SwitchToggleStyle())
                                .onChange(of: launchAtLogin) { value in
                                    LaunchAtLogin.shared.setLaunchAtLogin(enabled: value)
                                }
                        }
                    }
                }
                
                SettingsSection(title: "History", icon: "clock", color: .blue) {
                    VStack(spacing: 12) {
                        SettingsRow(
                            title: "Maximum History Size",
                            description: "Number of items to keep in clipboard history",
                            icon: "list.number"
                        ) {
                            HStack {
                                Text("\(maxHistorySize)")
                                    .foregroundColor(.secondary)
                                Stepper("", value: $maxHistorySize, in: 10...1000, step: 10)
                                    .labelsHidden()
                            }
                        }
                    }
                }
                
                SettingsSection(title: "iCloud Sync", icon: "icloud", color: .cyan) {
                    iCloudSyncToggleView
                }
            }
            .padding()
        }
        .alert("Enable iCloud Sync?", isPresented: $showingEnableAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Enable") {
                Task {
                    await syncManager.enableCloudKitSync()
                }
            }
        } message: {
            Text("This will sync your clipboard history to iCloud using your keychain credentials. Your data will be encrypted and available on all your devices signed in to the same iCloud account.")
        }
        .alert("Disable iCloud Sync?", isPresented: $showingDisableAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Disable", role: .destructive) {
                syncManager.disableCloudKitSync()
            }
        } message: {
            Text("This will stop syncing your clipboard history to iCloud. Your local data will remain intact.")
        }
    }
    
    @ViewBuilder
    private var iCloudSyncToggleView: some View {
        VStack(spacing: 12) {
            SettingsRow(
                title: "Sync to iCloud",
                description: syncManager.userWantsCloudKitSync ? 
                    "Clipboard history is synced across all your devices" : 
                    "Enable to sync clipboard history across devices",
                icon: syncManager.userWantsCloudKitSync ? "icloud.fill" : "icloud"
            ) {
                VStack(alignment: .trailing, spacing: 4) {
                    Toggle("", isOn: .constant(syncManager.userWantsCloudKitSync))
                        .toggleStyle(SwitchToggleStyle())
                        .disabled(true)
                        .onTapGesture {
                            if syncManager.userWantsCloudKitSync {
                                showingDisableAlert = true
                            } else {
                                showingEnableAlert = true
                            }
                        }
                    
                    if !syncManager.userWantsCloudKitSync {
                        Button("Enable") {
                            showingEnableAlert = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    } else if syncManager.userWantsCloudKitSync && !syncManager.isCloudKitAvailable {
                        Text("Setup Required")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    } else if syncManager.accountStatus != .available {
                        Text("Sign in to iCloud")
                            .font(.caption2)
                            .foregroundColor(.red)
                    } else {
                        HStack {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                            Text("Active")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            
            if syncManager.userWantsCloudKitSync {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                        .font(.caption)
                    
                    Text("Visit the Sync tab for detailed configuration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
    }
}

struct SimpleEnhancedShortcutsView: View {
    @AppStorage("openHotkey") private var openHotkeyData: Data?
    @AppStorage("pasteHotkey") private var pasteHotkeyData: Data?
    @AppStorage("clearHistoryHotkey") private var clearHistoryHotkeyData: Data?
    @AppStorage("togglePinHotkey") private var togglePinHotkeyData: Data?
    @AppStorage("searchHotkey") private var searchHotkeyData: Data?
    @AppStorage("copyCurrentHotkey") private var copyCurrentHotkeyData: Data?
    @AppStorage("showHelpHotkey") private var showHelpHotkeyData: Data?
    @AppStorage("duplicateItemHotkey") private var duplicateItemHotkeyData: Data?
    @AppStorage("favoriteItemHotkey") private var favoriteItemHotkeyData: Data?
    @AppStorage("exportHistoryHotkey") private var exportHistoryHotkeyData: Data?
    
    @State private var shortcuts: [ShortcutItem] = []
    @State private var showingResetAlert = false
    @State private var selectedCategory: ShortcutCategory = .primary
    
    var body: some View {
        VStack(spacing: 0) {
            // Beautiful header with gradient
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "keyboard")
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Keyboard Shortcuts")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Customize all keyboard shortcuts for ClipboardManager")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 8) {
                        Button("Reset All") {
                            showingResetAlert = true
                        }
                        .buttonStyle(ModernButtonStyle(color: .orange))
                        
                        Button("Export") {
                            exportShortcuts()
                        }
                        .buttonStyle(ModernButtonStyle(color: .blue))
                    }
                }
                
                // Category filter
                HStack {
                    Text("Category:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Picker("Category", selection: $selectedCategory) {
                        Text("Primary").tag(ShortcutCategory.primary)
                        Text("Secondary").tag(ShortcutCategory.secondary)
                        Text("Advanced").tag(ShortcutCategory.advanced)
                        Text("All").tag(ShortcutCategory.all)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 300)
                    
                    Spacer()
                }
            }
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.primary.opacity(0.02), Color.primary.opacity(0.05)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // Beautiful shortcuts table
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Table header
                    HStack {
                        Text("Action")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("Description")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("Shortcut")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(width: 160, alignment: .center)
                        
                        Text("Category")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(width: 100, alignment: .center)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.primary.opacity(0.05))
                    .overlay(
                        Rectangle()
                            .fill(Color.primary.opacity(0.1))
                            .frame(height: 1),
                        alignment: .bottom
                    )
                    
                    // Shortcuts rows
                    ForEach(filteredShortcuts) { shortcut in
                        ShortcutTableRow(shortcut: shortcut) { updatedShortcut in
                            updateShortcut(updatedShortcut)
                        }
                    }
                }
            }
            .background(Color(.controlBackgroundColor))
        }
        .onAppear {
            loadShortcuts()
        }
        .alert("Reset All Shortcuts", isPresented: $showingResetAlert) {
            Button("Reset", role: .destructive) {
                resetAllShortcuts()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will reset all keyboard shortcuts to their default values.")
        }
    }
    
    private var filteredShortcuts: [ShortcutItem] {
        if selectedCategory == .all {
            return shortcuts
        }
        return shortcuts.filter { $0.category == selectedCategory }
    }
    
    // ... rest of the shortcuts implementation
    private func loadShortcuts() {
        shortcuts = [
            // Primary shortcuts
            ShortcutItem(
                id: "open",
                name: "Open Clipboard Manager",
                description: "Show the clipboard history menu",
                icon: "list.clipboard",
                category: .primary,
                hotkey: loadHotkey(from: openHotkeyData) ?? Hotkey(keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(cmdKey | shiftKey))
            ),
            ShortcutItem(
                id: "paste",
                name: "Paste Selected Item",
                description: "Paste the currently selected clipboard item",
                icon: "doc.on.clipboard",
                category: .primary,
                hotkey: loadHotkey(from: pasteHotkeyData) ?? Hotkey(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | shiftKey))
            ),
            ShortcutItem(
                id: "copyCurrentItem",
                name: "Copy Current Item",
                description: "Copy the current item to system clipboard",
                icon: "doc.on.doc",
                category: .primary,
                hotkey: loadHotkey(from: copyCurrentHotkeyData) ?? Hotkey(keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(cmdKey | optionKey))
            ),
            ShortcutItem(
                id: "search",
                name: "Search Clipboard",
                description: "Open search interface for clipboard items",
                icon: "magnifyingglass",
                category: .primary,
                hotkey: loadHotkey(from: searchHotkeyData) ?? Hotkey(keyCode: UInt32(kVK_ANSI_F), modifiers: UInt32(cmdKey | shiftKey))
            ),
            
            // Secondary shortcuts
            ShortcutItem(
                id: "togglePin",
                name: "Toggle Pin",
                description: "Pin or unpin the selected clipboard item",
                icon: "pin",
                category: .secondary,
                hotkey: loadHotkey(from: togglePinHotkeyData) ?? Hotkey(keyCode: UInt32(kVK_ANSI_P), modifiers: UInt32(cmdKey | shiftKey))
            ),
            ShortcutItem(
                id: "favoriteItem",
                name: "Toggle Favorite",
                description: "Mark or unmark item as favorite",
                icon: "heart",
                category: .secondary,
                hotkey: loadHotkey(from: favoriteItemHotkeyData) ?? Hotkey(keyCode: UInt32(kVK_ANSI_F), modifiers: UInt32(cmdKey | optionKey))
            ),
            ShortcutItem(
                id: "duplicateItem",
                name: "Duplicate Item",
                description: "Create a copy of the selected item",
                icon: "doc.on.doc",
                category: .secondary,
                hotkey: loadHotkey(from: duplicateItemHotkeyData) ?? Hotkey(keyCode: UInt32(kVK_ANSI_D), modifiers: UInt32(cmdKey | shiftKey))
            ),
            ShortcutItem(
                id: "showHelp",
                name: "Show Help",
                description: "Display help and keyboard shortcuts",
                icon: "questionmark.circle",
                category: .secondary,
                hotkey: loadHotkey(from: showHelpHotkeyData) ?? Hotkey(keyCode: UInt32(kVK_ANSI_H), modifiers: UInt32(cmdKey | shiftKey))
            ),
            
            // Advanced shortcuts
            ShortcutItem(
                id: "clearHistory",
                name: "Clear All History",
                description: "Clear all clipboard history items",
                icon: "trash.circle",
                category: .advanced,
                hotkey: loadHotkey(from: clearHistoryHotkeyData) ?? Hotkey(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(cmdKey | shiftKey))
            ),
            ShortcutItem(
                id: "exportHistory",
                name: "Export History",
                description: "Export clipboard history to file",
                icon: "square.and.arrow.up",
                category: .advanced,
                hotkey: loadHotkey(from: exportHistoryHotkeyData) ?? Hotkey(keyCode: UInt32(kVK_ANSI_E), modifiers: UInt32(cmdKey | shiftKey | optionKey))
            )
        ]
    }
    
    private func loadHotkey(from data: Data?) -> Hotkey? {
        guard let data = data else { return nil }
        return try? JSONDecoder().decode(Hotkey.self, from: data)
    }
    
    private func updateShortcut(_ shortcut: ShortcutItem) {
        if let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) {
            shortcuts[index] = shortcut
        }
        saveShortcut(shortcut)
        NotificationCenter.default.post(name: .reloadHotkeys, object: nil, userInfo: nil)
    }
    
    private func saveShortcut(_ shortcut: ShortcutItem) {
        let data = try? JSONEncoder().encode(shortcut.hotkey)
        
        switch shortcut.id {
        case "open":
            openHotkeyData = data
        case "paste":
            pasteHotkeyData = data
        case "clearHistory":
            clearHistoryHotkeyData = data
        case "togglePin":
            togglePinHotkeyData = data
        case "search":
            searchHotkeyData = data
        case "copyCurrentItem":
            copyCurrentHotkeyData = data
        case "showHelp":
            showHelpHotkeyData = data
        case "duplicateItem":
            duplicateItemHotkeyData = data
        case "favoriteItem":
            favoriteItemHotkeyData = data
        case "exportHistory":
            exportHistoryHotkeyData = data
        default:
            break
        }
    }
    
    private func resetAllShortcuts() {
        openHotkeyData = nil
        pasteHotkeyData = nil
        clearHistoryHotkeyData = nil
        togglePinHotkeyData = nil
        searchHotkeyData = nil
        copyCurrentHotkeyData = nil
        showHelpHotkeyData = nil
        duplicateItemHotkeyData = nil
        favoriteItemHotkeyData = nil
        exportHistoryHotkeyData = nil
        loadShortcuts()
        NotificationCenter.default.post(name: .reloadHotkeys, object: nil, userInfo: nil)
    }
    
    private func exportShortcuts() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "ClipboardManager_Shortcuts.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let exportData = shortcuts.map { shortcut in
                    [
                        "id": shortcut.id,
                        "name": shortcut.name,
                        "description": shortcut.description,
                        "keyCode": shortcut.hotkey.keyCode,
                        "modifiers": shortcut.hotkey.modifiers
                    ]
                }
                
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
                    try jsonData.write(to: url)
                } catch {
                    print("Failed to export shortcuts: \(error)")
                }
            }
        }
    }
}

struct SimpleAppearanceSettingsView: View {
    @AppStorage("theme") private var theme = "system"
    @AppStorage("sidebarPosition") private var sidebarPosition = "right"

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SettingsSection(title: "Theme", icon: "paintpalette", color: .pink) {
                    VStack(spacing: 12) {
                        SettingsRow(
                            title: "Appearance",
                            description: "Choose your preferred theme",
                            icon: "circle.lefthalf.filled"
                        ) {
                            Picker("Theme", selection: $theme) {
                                Text("System").tag("system")
                                Text("Light").tag("light")
                                Text("Dark").tag("dark")
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 200)
                            .onChange(of: theme) { _ in
                                NotificationCenter.default.post(name: .applyTheme, object: nil, userInfo: nil)
                            }
                        }
                    }
                }
                
                SettingsSection(title: "Layout", icon: "rectangle.3.group", color: .blue) {
                    VStack(spacing: 12) {
                        SettingsRow(
                            title: "Sidebar Position",
                            description: "Choose where the clipboard sidebar appears",
                            icon: "sidebar.right"
                        ) {
                            Picker("Sidebar Position", selection: $sidebarPosition) {
                                Label("Right", systemImage: "sidebar.right").tag("right")
                                Label("Left", systemImage: "sidebar.left").tag("left")
                                Label("Top", systemImage: "rectangle.topthird.inset").tag("top")
                                Label("Bottom", systemImage: "rectangle.bottomthird.inset").tag("bottom")
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(width: 120)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct SimpleAdvancedSettingsView: View {
    @AppStorage("debugMode") private var debugMode = false
    @AppStorage("enableAnalytics") private var enableAnalytics = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SettingsSection(title: "Developer", icon: "chevron.left.forwardslash.chevron.right", color: .gray) {
                    VStack(spacing: 12) {
                        SettingsRow(
                            title: "Debug Mode",
                            description: "Enable detailed logging and debugging",
                            icon: "ladybug"
                        ) {
                            Toggle("", isOn: $debugMode)
                                .toggleStyle(SwitchToggleStyle())
                        }
                        
                        SettingsRow(
                            title: "Enable Analytics",
                            description: "Help improve the app by sharing usage data",
                            icon: "chart.bar"
                        ) {
                            Toggle("", isOn: $enableAnalytics)
                                .toggleStyle(SwitchToggleStyle())
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Shortcut Types
struct ShortcutItem: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let category: ShortcutCategory
    var hotkey: Hotkey
}

enum ShortcutCategory: CaseIterable {
    case primary
    case secondary
    case advanced
    case all
    
    var displayName: String {
        switch self {
        case .primary:
            return "Primary"
        case .secondary:
            return "Secondary"
        case .advanced:
            return "Advanced"
        case .all:
            return "All"
        }
    }
    
    var color: Color {
        switch self {
        case .primary:
            return .blue
        case .secondary:
            return .green
        case .advanced:
            return .orange
        case .all:
            return .gray
        }
    }
}

// MARK: - Supporting UI Components
struct ShortcutTableRow: View {
    let shortcut: ShortcutItem
    let onUpdate: (ShortcutItem) -> Void
    
    @State private var currentHotkey: Hotkey
    @State private var isHovered = false
    
    init(shortcut: ShortcutItem, onUpdate: @escaping (ShortcutItem) -> Void) {
        self.shortcut = shortcut
        self.onUpdate = onUpdate
        self._currentHotkey = State(initialValue: shortcut.hotkey)
    }
    
    var body: some View {
        HStack {
            // Action column
            HStack(spacing: 12) {
                Image(systemName: shortcut.icon)
                    .font(.title3)
                    .foregroundColor(shortcut.category.color)
                    .frame(width: 20, height: 20)
                
                Text(shortcut.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Description column
            Text(shortcut.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Shortcut column
            HotkeyRecorderView(hotkey: $currentHotkey)
                .frame(width: 160)
                .onChange(of: currentHotkey) { newHotkey in
                    var updatedShortcut = shortcut
                    updatedShortcut.hotkey = newHotkey
                    onUpdate(updatedShortcut)
                }
            
            // Category column
            Text(shortcut.category.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(shortcut.category.color)
                )
                .frame(width: 100, alignment: .center)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        )
        .overlay(
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(height: 1),
            alignment: .bottom
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}
