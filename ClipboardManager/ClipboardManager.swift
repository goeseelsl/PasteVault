import Cocoa
import CoreData
import Vision
import Carbon
import ApplicationServices

class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()
    private let pasteboard = NSPasteboard.general
    private var timer: Timer?
    private var lastChangeCount: Int
    @Published var updateTrigger = false
    
    // Maximum history items to keep (Clipy-style limit)
    private let maxHistory = 1000
    
    // Performance optimization: Skip monitoring when we're doing internal paste operations
    private var isInternalPasteOperation = false
    private let pasteOperationQueue = DispatchQueue(label: "paste-operations", qos: .userInteractive)
    
    // Cache accessibility permission status to avoid repeated system calls
    private var accessibilityPermissionGranted: Bool = false
    private var permissionCheckPerformed: Bool = false

    private init() {
        self.lastChangeCount = pasteboard.changeCount
        print("🚀 ClipboardManager initializing with change count: \(lastChangeCount)")
        
        // Check if this is a fresh installation and reset permissions if needed
        checkForFreshInstallationAndResetPermissions()
        
        // Single permission check at startup for non-sandboxed app
        checkAndRequestAccessibilityPermissions()
        startMonitoring()
        
        // Test Core Data by adding a test item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("🧪 Adding test item to verify Core Data...")
            self.addItem(content: "Test startup item - \(Date())")
        }
        
        print("✅ ClipboardManager initialization complete")
    }
    
    // MARK: - Permission Reset for Fresh Installation
    
    private func checkForFreshInstallationAndResetPermissions() {
        let appVersionKey = "ClipboardManager_AppVersion"
        let permissionResetKey = "ClipboardManager_PermissionsReset"
        let currentVersion = "1.1.6"
        
        let savedVersion = UserDefaults.standard.string(forKey: appVersionKey)
        let permissionsAlreadyReset = UserDefaults.standard.bool(forKey: permissionResetKey)
        
        // Reset permissions if:
        // 1. This is a completely fresh installation (no saved version)
        // 2. The version has changed (app update)
        // 3. Permissions haven't been reset for this version yet
        if savedVersion == nil || savedVersion != currentVersion || !permissionsAlreadyReset {
            print("🔄 Fresh installation or version change detected - resetting all permissions...")
            resetAllPermissions()
            
            // Mark this version as having reset permissions
            UserDefaults.standard.set(currentVersion, forKey: appVersionKey)
            UserDefaults.standard.set(true, forKey: permissionResetKey)
            UserDefaults.standard.synchronize()
            
            print("✅ Permission reset complete for version \(currentVersion)")
        } else {
            print("ℹ️ Existing installation detected - keeping current permission state")
        }
    }
    
    public func resetAllPermissions() {
        print("🧹 Resetting all permission caches and preferences...")
        
        // Reset internal permission cache
        accessibilityPermissionGranted = false
        permissionCheckPerformed = false
        
        // Clear all permission-related UserDefaults
        let permissionKeys = [
            "ClipboardManager_AccessibilityGranted",
            "ClipboardManager_PermissionCheckPerformed", 
            "ClipboardManager_SkipPermissionPrompts",
            "ClipboardManager_AutoGrantPermissions",
            "NSApplicationCrashOnExceptions",
            "AppleLanguages",
            "AppleLocale"
        ]
        
        for key in permissionKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        // Clear any cached system permission states
        UserDefaults.standard.removeObject(forKey: "TrustedAccessibilityApps")
        UserDefaults.standard.synchronize()
        
        print("🔄 Permission caches cleared - fresh permission prompts will be shown")
        
        // Force immediate re-check of permissions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.forcePermissionRecheck()
        }
    }
    
    private func forcePermissionRecheck() {
        print("🔍 Forcing fresh permission check...")
        accessibilityPermissionGranted = false
        permissionCheckPerformed = false
        checkAndRequestAccessibilityPermissions()
    }
    
    // MARK: - Accessibility Permissions (Non-Sandboxed Simple Detection)
    
    private func checkAndRequestAccessibilityPermissions() {
        print("🔐 Checking accessibility permissions at startup (non-sandboxed app)...")
        
        // Only check once to avoid repeated system dialogs
        guard !permissionCheckPerformed else {
            print("🔄 Permission check already performed this session")
            return
        }
        
        permissionCheckPerformed = true
        
        // Single check for non-sandboxed apps - cache the result
        accessibilityPermissionGranted = AXIsProcessTrusted()
        
        if accessibilityPermissionGranted {
            print("✅ Accessibility permissions already granted - app ready to use!")
        } else {
            print("⚠️ Accessibility permissions not granted - automatic paste operations will be disabled")
            print("ℹ️ Users can manually grant permissions in System Preferences > Privacy & Security > Accessibility")
        }
    }
    
    // Get cached permission status to avoid repeated system calls
    private func hasAccessibilityPermissions() -> Bool {
        if !permissionCheckPerformed {
            // Fallback: check once if not already done
            checkAndRequestAccessibilityPermissions()
        }
        return accessibilityPermissionGranted
    }
    
    // Public function to refresh permissions if user grants them manually
    func refreshAccessibilityPermissions() {
        print("🔄 Manually refreshing accessibility permissions...")
        permissionCheckPerformed = false
        checkAndRequestAccessibilityPermissions()
    }
    
    private func showSimpleAccessibilitySetup() {
        print("� Requesting accessibility permissions (non-sandboxed app)")
        
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = """
                ClipboardManager needs accessibility permission to paste content automatically.
                
                1. Click "Open System Settings" below
                2. Find "ClipboardManager" in the list
                3. Enable the checkbox next to it
                4. Return to ClipboardManager
                
                This is a one-time setup for this non-sandboxed version.
                """
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Skip for Now")
            alert.alertStyle = .informational
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                print("� Opening accessibility settings...")
                
                // Direct path to accessibility settings
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    if !NSWorkspace.shared.open(url) {
                        // Fallback for newer macOS versions
                        if let settingsUrl = URL(string: "x-apple.systempreferences:com.apple.Settings.PrivacySecurity.extension") {
                            NSWorkspace.shared.open(settingsUrl)
                        }
                    }
                }
            } else {
                print("ℹ️ User chose to skip accessibility setup")
            }
        }
    }
    
    // MARK: - Clipboard Monitoring

    func startMonitoring() {
        print("🔄 Starting clipboard monitoring...")
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
        print("⏰ Clipboard monitoring timer started (interval: 0.5s)")
    }

    func stopMonitoring() {
        print("Stopping clipboard monitoring.")
        timer?.invalidate()
        timer = nil
    }

    private func checkPasteboard() {
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastChangeCount else {
            return
        }
        
        print("📋 Pasteboard change detected! Count: \(lastChangeCount) → \(currentChangeCount)")
        
        // Skip monitoring during internal paste operations to prevent duplicates
        guard !isInternalPasteOperation else {
            print("⏭️  Skipping - internal paste operation in progress")
            lastChangeCount = currentChangeCount
            return
        }
        
        lastChangeCount = currentChangeCount

        if let items = pasteboard.pasteboardItems {
            print("📦 Found \(items.count) pasteboard item(s)")
            for (index, item) in items.enumerated() {
                print("📄 Item \(index): types = \(item.types)")
                
                // Check for image data first (screenshots, images)
                if let imageData = item.data(forType: .tiff) ?? item.data(forType: .png) {
                    print("🖼️  Found image data (\(imageData.count) bytes)")
                    // Process image asynchronously to prevent crashes
                    processImageData(imageData)
                } else if let string = item.string(forType: .string) {
                    print("📝 Found string content: \(string.prefix(50))...")
                    addItem(content: string)
                } else {
                    print("❓ Found pasteboard item with unknown content types: \(item.types)")
                }
            }
        } else {
            print("⚠️  No pasteboard items found")
        }
    }
    
    private func processImageData(_ imageData: Data) {
        // Process image on background queue to prevent UI blocking
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Create NSImage from data with error handling
            guard let image = NSImage(data: imageData) else {
                print("⚠️ Failed to create NSImage from data")
                return
            }
            
            print("📸 Processing image - Size: \(image.size), Data: \(imageData.count) bytes")
            
            // Get image dimensions for validation
            let imageSize = image.size
            guard imageSize.width > 0 && imageSize.height > 0 else {
                print("⚠️ Invalid image dimensions: \(imageSize)")
                return
            }
            
            // Switch back to main queue for Core Data operations
            DispatchQueue.main.async {
                self.addItem(content: nil, imageData: imageData)
            }
        }
    }
    
    private func addItem(content: String? = nil, imageData: Data? = nil) {
        print("💾 Adding item to clipboard history...")
        
        // Ensure we're on the main thread for Core Data operations
        DispatchQueue.main.async {
            let newItem = ClipboardItem(context: self.viewContext)
            newItem.id = UUID()
            newItem.createdAt = Date()
            
            if let content = content {
                print("📝 Adding text item: \(content.prefix(50))...")
                // Text content
                newItem.decryptedContent = content
                newItem.category = "Text"
                self.saveContext()
                self.notifyUIUpdate()
            }
            
            if let imageData = imageData {
                print("🖼️  Adding image item (\(imageData.count) bytes)")
                // Image content
                newItem.imageData = imageData
                newItem.category = "Image"
                
                self.saveContext()
                self.notifyUIUpdate()
            }
            
            self.cullHistory()
            print("✅ Item added successfully")
        }
    }
    
    private func cullHistory() {
        let fetchRequest: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        
        do {
            let items = try viewContext.fetch(fetchRequest)
            if items.count > maxHistory {
                let itemsToDelete = items.prefix(items.count - maxHistory)
                for item in itemsToDelete {
                    viewContext.delete(item)
                }
                saveContext()
                print("🗑️ Culled \(itemsToDelete.count) old items, keeping \(maxHistory) most recent")
            }
        } catch {
            print("❌ Error culling history: \(error)")
        }
    }
    
    // MARK: - Core Data
    
    var persistentContainer: NSPersistentContainer {
        return PersistenceController.shared.container
    }
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Paste Operations
    
    func copyToPasteboard(item: ClipboardItem) {
        print("📋 Copying item to pasteboard...")
        
        // Clear pasteboard first for clean state
        pasteboard.clearContents()
        
        // Determine what type of content we have using decrypted data
        if let imageData = item.imageData {
            // Handle image content
            print("📸 Setting image data to pasteboard (\(imageData.count) bytes)")
            
            // Create NSImage to validate the data
            guard let image = NSImage(data: imageData) else {
                print("❌ Failed to create NSImage from stored data")
                return
            }
            
            print("📸 Image validated - Size: \(image.size)")
            
            // Primary method: Use writeObjects which handles multiple image formats
            let success = pasteboard.writeObjects([image])
            
            if success {
                print("✅ Image written to pasteboard using writeObjects")
            } else {
                print("⚠️ writeObjects failed, trying manual approach...")
                
                // Fallback 1: Use declareTypes with multiple formats
                pasteboard.declareTypes([.tiff, .png, .pdf], owner: nil)
                
                // Try to get TIFF representation
                if let tiffData = image.tiffRepresentation {
                    pasteboard.setData(tiffData, forType: .tiff)
                    print("📋 Image written as TIFF data (\(tiffData.count) bytes)")
                } else {
                    // Fallback 2: Write raw image data as TIFF
                    pasteboard.setData(imageData, forType: .tiff)
                    print("📋 Raw image data written as TIFF (\(imageData.count) bytes)")
                }
            }
            
            // Verify image was written
            if let retrievedImage = pasteboard.readObjects(forClasses: [NSImage.self])?.first as? NSImage {
                print("✅ Image verified in pasteboard - size: \(retrievedImage.size)")
            } else if let retrievedData = pasteboard.data(forType: .tiff) {
                print("✅ Image TIFF data verified in pasteboard - size: \(retrievedData.count) bytes")
            } else {
                print("⚠️ Could not verify image in pasteboard")
            }
            
        } else if let content = item.decryptedContent {
            // Handle text content using Clipy's proven approach
            print("📝 Setting text content to pasteboard: \(content.prefix(50))...")
            
            // Use declareTypes first for better compatibility (Clipy pattern)
            pasteboard.declareTypes([.string], owner: nil)
            let success = pasteboard.setString(content, forType: .string)
            
            if success {
                print("✅ Text content set successfully")
            } else {
                print("❌ Failed to set text content")
                return
            }
            
            // Verify the content was written correctly
            if let pasteboardContent = pasteboard.string(forType: .string) {
                print("✅ Pasteboard verification: \(pasteboardContent.prefix(50))...")
            } else {
                print("⚠️ Could not verify text content in pasteboard")
            }
        }
        
        // Note: synchronize() was removed in newer macOS versions, but the pasteboard
        // is automatically synchronized when we set data
        let changeCount = pasteboard.changeCount
        print("📋 Pasteboard change count: \(changeCount)")
        
        // Update lastChangeCount to prevent re-monitoring this change
        lastChangeCount = changeCount
        
        print("🎯 Copy operation complete")
    }
    
    func performPasteOperation(item: ClipboardItem, completion: @escaping (Bool) -> Void = { _ in }) {
        print("🚀 Starting paste operation...")
        
        // Debug: Print current pasteboard state
        debugPasteboardState()
        
        // Set flag to prevent monitoring during paste
        isInternalPasteOperation = true
        
        // Always copy to pasteboard first
        copyToPasteboard(item: item)
        
        // Debug: Print pasteboard state after copying
        print("📋 After copyToPasteboard:")
        debugPasteboardState()
        
        // Check accessibility permissions for programmatic pasting (direct check for paste operations)
        let accessEnabled = AXIsProcessTrusted()
        print("🔐 Direct permission check for paste: \(accessEnabled ? "GRANTED" : "NOT GRANTED")")
        
        if accessEnabled {
            print("✅ Accessibility enabled - performing programmatic paste")
            // Simplified timing - paste immediately after copying
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("🎯 About to call performProgrammaticPaste()")
                let pasteSuccess = self.performProgrammaticPaste()
                print("📝 Paste operation result: \(pasteSuccess)")
                
                // Quick cleanup with coordinated hotkey re-enabling
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.isInternalPasteOperation = false
                    
                    print("🔄 Cleanup: isInternalPasteOperation set to false")
                    // Send coordinated notifications to re-enable everything
                    NotificationCenter.default.post(
                        name: NSNotification.Name("PasteOperationCompleted"),
                        object: nil,
                        userInfo: ["success": pasteSuccess, "timestamp": Date()]
                    )
                    
                    print("📢 Posted PasteOperationCompleted notification")
                    completion(pasteSuccess)
                }
            }
        } else {
            print("⚠️ No accessibility permissions - content copied, user must paste manually")
            
            // Show brief notification that content is ready
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Content Copied"
                alert.informativeText = "Content has been copied to clipboard. Press ⌘V to paste."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                
                // Auto-dismiss after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if alert.window.isVisible {
                        alert.window.performClose(nil)
                    }
                }
                
                alert.runModal()
            }
            
            // Quick cleanup for manual paste mode
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.isInternalPasteOperation = false
                
                // Send coordinated notifications to re-enable everything
                NotificationCenter.default.post(
                    name: NSNotification.Name("PasteOperationCompleted"),
                    object: nil,
                    userInfo: ["success": true, "timestamp": Date(), "manual": true]
                )
                
                completion(true)
            }
        }
    }
    
    private func performProgrammaticPaste() -> Bool {
        print("🎯 performProgrammaticPaste() called - delegating to PasteHelper")
        // Use PasteHelper for consistent paste behavior
        PasteHelper.paste()
        print("✅ PasteHelper.paste() completed")
        return true
    }
    
    private func debugPasteboardState() {
        let changeCount = pasteboard.changeCount
        let stringContent = pasteboard.string(forType: .string)
        let imageContent = pasteboard.readObjects(forClasses: [NSImage.self])?.first as? NSImage
        
        print("🔍 Pasteboard Debug:")
        print("  • Change count: \(changeCount)")
        print("  • String content: \(stringContent?.prefix(50) ?? "nil")...")
        print("  • Image content: \(imageContent?.size ?? CGSize.zero)")
        print("  • Available types: \(pasteboard.types ?? [])")
    }
    
    // MARK: - Core Data Helpers
    
    private func saveContext() {
        do {
            try viewContext.save()
            print("Context saved successfully")
            
            // Post notification that context was saved
            NotificationCenter.default.post(name: .NSManagedObjectContextDidSave, object: viewContext)
        } catch {
            let nsError = error as NSError
            print("❌ Core Data save error: \(nsError), \(nsError.userInfo)")
        }
    }
    
    private func notifyUIUpdate() {
        // Trigger UI update by toggling the published property
        DispatchQueue.main.async {
            self.updateTrigger.toggle()
            
            // Also post a custom notification for immediate UI updates
            NotificationCenter.default.post(name: NSNotification.Name("ClipboardItemsUpdated"), object: nil)
        }
    }
}

extension NSImage {
    var pngData: Data? {
        guard let tiffRepresentation = tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
        return bitmapImage.representation(using: .png, properties: [:])
    }
}
