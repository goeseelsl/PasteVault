import Cocoa
import SwiftUI
import Carbon
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    var statusBarItem: NSStatusItem!
    var edgeWindow: EdgeWindow?
    var settingsWindow: NSWindow?
    var settingsHostingController: NSHostingController<SimpleSettingsView>?
    var windowHostingController: NSHostingController<AnyView>?
    var isEdgeWindowShown = false

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Set up notification observers with higher priority for hotkey reload
        NotificationCenter.default.addObserver(
            forName: .reloadHotkeys,
            object: nil,
            queue: OperationQueue.main, // Force main queue for immediate execution
            using: { [weak self] _ in
                self?.registerHotkeys()
            }
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyTheme),
            name: .applyTheme,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(disableGlobalHotkeys),
            name: .disableGlobalHotkeys,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(enableGlobalHotkeys),
            name: .enableGlobalHotkeys,
            object: nil
        )
        
        // Create the status bar item
        self.statusBarItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))

        if let button = self.statusBarItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard Manager")
            button.action = #selector(toggleEdgeWindow(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Create the content view for the edge window
        let contentView = ContentView()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        
        // Create the hosting controller but don't create the window yet
        windowHostingController = NSHostingController<AnyView>(rootView: AnyView(contentView))
        
        // Configure the hosting controller to use all available space
        if let controller = windowHostingController {
            controller.view.translatesAutoresizingMaskIntoConstraints = false
            controller.view.wantsLayer = true
            // Disable intrinsic content size to allow the view to fill the window
            controller.view.setContentHuggingPriority(.defaultLow, for: .vertical)
            controller.view.setContentHuggingPriority(.defaultLow, for: .horizontal)
            controller.view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
            controller.view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        
        _ = ClipboardManager.shared

        // Register hotkey
        registerHotkeys()
        
        // Request notification permissions (only if running as a proper app bundle)
        if #available(macOS 10.14, *), Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
                if let error = error {
                    print("Notification permission error: \(error)")
                }
            }
        }
        
        // Add Touch Bar support
        if #available(OSX 10.12.2, *) {
            NSApplication.shared.isAutomaticCustomizeTouchBarMenuItemEnabled = true
        }
    }

    @objc func reloadHotkeys() {
        registerHotkeys()
    }
    
    @objc func applyTheme() {
        let theme = UserDefaults.standard.string(forKey: "theme") ?? "system"
        if theme == "dark" {
            NSApp.appearance = NSAppearance(named: .darkAqua)
        } else if theme == "light" {
            NSApp.appearance = NSAppearance(named: .aqua)
        } else {
            NSApp.appearance = nil
        }
    }
    
    @objc func disableGlobalHotkeys() {
        HotkeysManager.shared.temporarilyDisable()
    }
    
    @objc func enableGlobalHotkeys() {
        HotkeysManager.shared.reenable()
    }
    
    func registerHotkeys() {
        // First, unregister all existing hotkeys to ensure a clean state
        HotkeysManager.shared.unregisterAll()
        
        // Define a helper function to reduce code duplication and improve performance
        func registerHotkey(key: String, defaultKeyCode: UInt32? = nil, defaultModifiers: UInt32? = nil, handler: @escaping () -> Void) {
            let hotkeyData = UserDefaults.standard.data(forKey: key)
            var hotkey: Hotkey?
            
            if let data = hotkeyData,
               let decodedHotkey = try? JSONDecoder().decode(Hotkey.self, from: data) {
                hotkey = decodedHotkey
            } else if let defaultKeyCode = defaultKeyCode, let defaultModifiers = defaultModifiers {
                hotkey = Hotkey(keyCode: defaultKeyCode, modifiers: defaultModifiers)
            }
            
            if let hotkey = hotkey {
                HotkeysManager.shared.register(keyCode: hotkey.keyCode, modifiers: hotkey.modifiers, handler: handler)
            }
        }
        
        // Register Open Clipboard History hotkey (prioritize this one)
        registerHotkey(key: "openHotkey", defaultKeyCode: UInt32(kVK_ANSI_C), defaultModifiers: UInt32(cmdKey | shiftKey)) { [weak self] in
            self?.toggleEdgeWindow(nil)
        }
        
        // Register all other hotkeys
        registerHotkey(key: "pasteHotkey") { [weak self] in
            self?.pasteFromHistory()
        }
        
        registerHotkey(key: "clearHistoryHotkey") { [weak self] in
            self?.clearHistory()
        }
        
        registerHotkey(key: "togglePinHotkey") { [weak self] in
            self?.togglePinOnMostRecent()
        }
        
        // Handle the edge case where registration failed
        let carbonManager = HotkeysManager.shared
        if carbonManager.activeHotkeysCount == 0 && carbonManager.isEnabled {
            // Registration failed, but we'll silently handle it
        }
    }

    @objc func toggleEdgeWindow(_ sender: AnyObject?) {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings(_:)), keyEquivalent: ","))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            statusBarItem.menu = menu
            statusBarItem.button?.performClick(nil)
            statusBarItem.menu = nil // Unset the menu so the edge window can be shown on left-click
        } else {
            // Check if the window is actually visible, regardless of the isEdgeWindowShown flag
            let windowActuallyVisible = edgeWindow?.isVisible ?? false
            
            // Use both the flag and actual window state to determine what to do
            if isEdgeWindowShown && windowActuallyVisible {
                closeEdgeWindow()
            } else {
                // If we think it's shown but it's not visible, correct our state
                if isEdgeWindowShown && !windowActuallyVisible {
                    isEdgeWindowShown = false
                }
                
                print("🔄 Opening edge window")
                // Activate the application first to ensure proper positioning
                NSApp.activate(ignoringOtherApps: true)
                
                // Small delay to ensure activation is complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.showEdgeWindow()
                }
            }
        }
    }
    
    private func showEdgeWindow() {
        print("🔍 showEdgeWindow called")
        guard let controller = windowHostingController else {
            print("❌ windowHostingController is nil")
            return
        }
        
        // Get user preference for sidebar position (default to right)
        let sidebarPosition = UserDefaults.standard.string(forKey: "sidebarPosition") ?? "right"
        let position = EdgeWindow.Position.fromString(sidebarPosition)
        
        // Create the edge window if it doesn't exist
        if edgeWindow == nil {
            print("⚠️ Creating new edge window")
            // For top/bottom positions, we want a window that spans the full width
            // For left/right positions, we want a window that spans the full height
            let widthOrHeight: CGFloat
            
            if position == .left || position == .right {
                widthOrHeight = 350 // Width for side panels
            } else {
                widthOrHeight = 400 // Height for top/bottom panels
            }
            
            edgeWindow = EdgeWindow(position: position, widthOrHeight: widthOrHeight)
            
            // Configure the hosting controller to fill the window
            if let window = edgeWindow {
                controller.view.frame = window.contentView?.bounds ?? NSRect(x: 0, y: 0, width: widthOrHeight, height: 1117)
                controller.view.autoresizingMask = [.width, .height]
            }
            
            edgeWindow?.contentViewController = controller
            edgeWindow?.delegate = self
        } else {
            print("📝 Reusing existing edge window")
            // Update position if the window already exists
            edgeWindow?.updatePosition(position)
        }
        
        guard let window = edgeWindow else {
            print("❌ Failed to create or access edge window")
            return
        }
        
        print("📊 Window state before showing: isVisible=\(window.isVisible), isKeyWindow=\(window.isKeyWindow)")
        
        // Force window to be key and front with multiple methods
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        
        // Ensure the app is active
        NSApp.activate(ignoringOtherApps: true)
        
        isEdgeWindowShown = true
        
        // Verify window is now showing
        print("📊 Window state after showing: isVisible=\(window.isVisible), isKeyWindow=\(window.isKeyWindow)")
        
        // If the window is still not visible, try a different approach
        if !window.isVisible {
            print("🔴 Window still not visible after showing, trying alternative approach")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                NSApp.activate(ignoringOtherApps: true)
                print("📊 Window state after alternative approach: isVisible=\(window.isVisible), isKeyWindow=\(window.isKeyWindow)")
            }
        }
    }
    
    func closeEdgeWindow() {
        // Start reloading hotkeys immediately, don't wait for window operations
        DispatchQueue.main.async { // Use async instead of asyncAfter for immediate execution
            self.registerHotkeys()
        }
        
        guard let window = edgeWindow else {
            isEdgeWindowShown = false
            return
        }
        window.orderOut(nil)
        isEdgeWindowShown = false
        print("📊 Window state after closing: isVisible=\(window.isVisible)")
    }
    
    func pasteFromHistory() {
        // Get the most recent clipboard item and paste it
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest = NSFetchRequest<ClipboardItem>(entityName: "ClipboardItem")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItem.createdAt, ascending: false)]
        fetchRequest.fetchLimit = 1
        
        do {
            let items = try context.fetch(fetchRequest)
            if let mostRecentItem = items.first {
                ClipboardManager.shared.copyToPasteboard(item: mostRecentItem)
                showNotification(title: "Pasted from History", message: "Most recent item pasted")
            }
        } catch {
            print("Error fetching most recent item: \(error)")
        }
    }
    
    func clearHistory() {
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "ClipboardItem")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
            showNotification(title: "History Cleared", message: "All clipboard history has been cleared")
        } catch {
            print("Error clearing history: \(error)")
        }
    }
    
    func togglePinOnMostRecent() {
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest = NSFetchRequest<ClipboardItem>(entityName: "ClipboardItem")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItem.createdAt, ascending: false)]
        fetchRequest.fetchLimit = 1
        
        do {
            let items = try context.fetch(fetchRequest)
            if let mostRecentItem = items.first {
                mostRecentItem.isPinned.toggle()
                try context.save()
                let status = mostRecentItem.isPinned ? "pinned" : "unpinned"
                showNotification(title: "Item \(status.capitalized)", message: "Most recent item \(status)")
            }
        } catch {
            print("Error toggling pin on most recent item: \(error)")
        }
    }
    
    private func showNotification(title: String, message: String) {
        if #available(macOS 10.14, *), Bundle.main.bundleIdentifier != nil {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = message
            content.sound = UNNotificationSound.default
            
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        } else {
            // Just print to console for command-line version
            print("📋 \(title): \(message)")
        }
    }

    @objc func openSettings(_ sender: AnyObject?) {
        // Always close existing window first to prevent multiple instances
        closeSettingsWindow()
        
        // Create a simple settings view that doesn't use complex SwiftUI features
        let settingsView = SimpleSettingsView()
        let hostingController = NSHostingController(rootView: settingsView)
        
        // Set minimum size to accommodate the new layout
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 650, height: 550)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 550),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false)
        
        window.center()
        window.setFrameAutosaveName("Settings")
        window.contentViewController = hostingController
        window.delegate = self
        window.title = "Clipboard Manager Settings"
        window.level = .floating
        window.isReleasedWhenClosed = false // Prevent premature deallocation
        
        // Store references to prevent deallocation
        settingsWindow = window
        settingsHostingController = hostingController
        
        // Ensure the window comes to the front
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
    
    private func closeSettingsWindow() {
        guard let window = settingsWindow else { return }
        
        // First, stop being the delegate to avoid callbacks during cleanup
        window.delegate = nil
        
        // Close the window first
        window.close()
        
        // Then clear references
        settingsWindow = nil
        settingsHostingController = nil
    }
    
    // Create and show the organization window
    @objc func openOrganizationWindow(_ sender: Any?) {
        // Close the edge window first (this will also close the sidebar)
        closeEdgeWindow()
        
        // First, activate the application to ensure proper window ordering
        NSApp.activate(ignoringOtherApps: true)
        
        // Check if window already exists and just focus it
        if let existingWindow = NSApp.windows.first(where: { $0.title == "Clipboard Organization" }) {
            existingWindow.makeKeyAndOrderFront(nil)
            existingWindow.orderFrontRegardless()
            return
        }
        
        // Create a new organization window controller
        let organizationWindowController = OrganizationWindowController()
        organizationWindowController.showWindow(nil)
        organizationWindowController.window?.orderFrontRegardless()
    }
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        applyTheme()
    }
    
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == settingsWindow {
            // Just clear the references - don't manipulate the window
            settingsWindow = nil
            settingsHostingController = nil
        }
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Just return true, let windowWillClose handle cleanup
        return true
    }
    
    deinit {
        // Ensure all resources are cleaned up
        closeEdgeWindow()
        closeSettingsWindow()
        HotkeysManager.shared.unregisterAll()
        
        // Remove any remaining notifications
        NotificationCenter.default.removeObserver(self)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up resources before terminating
        closeEdgeWindow()
        closeSettingsWindow()
    }
}
