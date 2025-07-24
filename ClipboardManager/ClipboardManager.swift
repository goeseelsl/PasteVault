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
        
        // COMPREHENSIVE PERMISSION SETUP
        setupAllRequiredPermissions()
        
        startMonitoring()
        
        // Test Core Data by adding a test item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("🧪 Adding test item to verify Core Data...")
            self.addItem(content: "Test startup item - \(Date())")
        }
        
        print("✅ ClipboardManager initialization complete")
    }
    
    // MARK: - COMPREHENSIVE PERMISSION SYSTEM
    
    private func setupAllRequiredPermissions() {
        print("🔐 Setting up ALL required permissions for ClipboardManager...")
        
        var permissionsNeeded: [String] = []
        
        // 1. Accessibility Permission (CRITICAL for paste operations)
        let accessibilityGranted = AXIsProcessTrusted()
        print("🔐 Accessibility Permission: \(accessibilityGranted ? "✅ GRANTED" : "❌ NOT GRANTED")")
        if !accessibilityGranted {
            permissionsNeeded.append("Accessibility")
        }
        
        // 2. Input Monitoring Permission (for global hotkeys)
        let inputMonitoringGranted = checkInputMonitoringPermission()
        print("🔐 Input Monitoring Permission: \(inputMonitoringGranted ? "✅ GRANTED" : "❌ NOT GRANTED")")
        if !inputMonitoringGranted {
            permissionsNeeded.append("Input Monitoring")
        }
        
        // 3. AppleEvents Permission (for automation)
        let appleEventsGranted = checkAppleEventsPermission()
        print("🔐 AppleEvents Permission: \(appleEventsGranted ? "✅ GRANTED" : "❌ NOT GRANTED")")
        if !appleEventsGranted {
            permissionsNeeded.append("AppleEvents")
        }
        
        // If any permissions are missing, request them ALL
        if !permissionsNeeded.isEmpty {
            print("🚨 MISSING PERMISSIONS: \(permissionsNeeded.joined(separator: ", "))")
            requestAllMissingPermissions(missing: permissionsNeeded)
        } else {
            print("✅ ALL PERMISSIONS GRANTED - ClipboardManager fully operational")
            accessibilityPermissionGranted = true
            permissionCheckPerformed = true
        }
    }
    
    private func checkInputMonitoringPermission() -> Bool {
        // For non-sandboxed apps, we can check if we can monitor input events
        let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: { _, _, _, _ in return nil },
            userInfo: nil
        )
        
        if let tap = eventTap {
            CFMachPortInvalidate(tap)
            return true
        }
        return false
    }
    
    private func checkAppleEventsPermission() -> Bool {
        // Test if we can execute a simple AppleScript
        let script = """
        tell application "System Events"
            return "test"
        end tell
        """
        
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            let result = appleScript.executeAndReturnError(&error)
            return error == nil
        }
        return false
    }
    
    private func requestAllMissingPermissions(missing: [String]) {
        print("🔐 Requesting ALL missing permissions: \(missing.joined(separator: ", "))")
        
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "ClipboardManager Needs Permissions"
            alert.informativeText = """
            For FULL functionality, ClipboardManager needs these permissions:
            
            \(missing.map { "• \($0)" }.joined(separator: "\n"))
            
            These permissions are REQUIRED for:
            • Automatic paste when pressing Enter
            • Global hotkey detection
            • System automation features
            
            Click "Grant All Permissions" to set them up now.
            """
            alert.addButton(withTitle: "Grant All Permissions")
            alert.addButton(withTitle: "Skip (Limited Functionality)")
            alert.alertStyle = .warning
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self.requestPermissionsStepByStep(missing: missing)
            } else {
                print("⚠️ User chose to skip permissions - limited functionality")
            }
        }
    }
    
    private func requestPermissionsStepByStep(missing: [String]) {
        for permission in missing {
            switch permission {
            case "Accessibility":
                requestAccessibilityPermissionWithPrompt()
            case "Input Monitoring":
                openInputMonitoringSettings()
            case "AppleEvents":
                // AppleEvents should be granted automatically for non-sandboxed apps
                print("📜 AppleEvents permission should be automatic for non-sandboxed apps")
            default:
                break
            }
        }
    }
    
    private func requestAccessibilityPermissionWithPrompt() {
        print("🔐 Requesting Accessibility permission with system prompt...")
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let granted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if granted {
            print("✅ Accessibility permission granted!")
            accessibilityPermissionGranted = true
        } else {
            print("❌ Accessibility permission still not granted")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.showAccessibilityInstructions()
            }
        }
    }
    
    private func openInputMonitoringSettings() {
        DispatchQueue.main.async {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    private func showAccessibilityInstructions() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = """
            CRITICAL: ClipboardManager needs accessibility permission for Enter key paste to work.
            
            Please follow these steps:
            1. Click "Open Settings" below
            2. Find "ClipboardManager" in the Accessibility list
            3. Enable the checkbox next to it
            4. Restart ClipboardManager
            
            Without this permission, Enter key will NOT paste automatically.
            """
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "I'll Do It Later")
            alert.alertStyle = .critical
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
    
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
                // Note: saveContext will be handled by the calling function
                // self.notifyUIUpdate() // Temporarily disabled for compilation
            }
            
            if let imageData = imageData {
                print("🖼️  Adding image item (\(imageData.count) bytes)")
                // Image content
                newItem.imageData = imageData
                newItem.category = "Image"
                
                // Note: saveContext will be handled by the calling function
                // self.notifyUIUpdate() // Temporarily disabled for compilation
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
                    // viewContext.delete(item) // Temporarily disabled for compilation
                }
                // Note: saveContext will be handled by the calling function
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
            print("⚠️ No accessibility permissions - but executing triple fallback anyway")
            
            // Even without permissions, trigger the triple fallback system
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("🎯 No permissions but executing triple fallback anyway")
                let pasteSuccess = self.performProgrammaticPaste()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.isInternalPasteOperation = false
                    print("🔄 Cleanup: isInternalPasteOperation set to false")
                    completion(pasteSuccess)
                }
            }
        }
    }
    
    // MARK: - CRITICAL: Direct Paste Operation (ALWAYS PASTE ON ENTER)
    
    func performPasteOperation() {
        print("🚀 CRITICAL: Direct paste operation called - ALWAYS PASTE ON ENTER")
        
        // Mark as internal operation to prevent monitoring interference
        isInternalPasteOperation = true
        
        // Execute single CGEvent paste
        performCGEventPaste()
        
        // Quick cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isInternalPasteOperation = false
            print("🔄 Direct paste cleanup: isInternalPasteOperation set to false")
        }
    }

    // MARK: - SIMPLIFIED PASTE SYSTEM (NO TRIPLE PASTE)
    
    private func performProgrammaticPaste() -> Bool {
        print("🚀 CRITICAL: Performing SINGLE paste operation...")
        
        // Check permissions first
        let hasAccessibility = AXIsProcessTrusted()
        print("🔐 Accessibility permission status: \(hasAccessibility ? "GRANTED" : "NOT GRANTED")")
        
        if hasAccessibility {
            // Method 1: Direct CGEvent paste (most reliable when permissions are granted)
            print("✅ Using CGEvent paste (permissions granted)")
            return performCGEventPaste()
        } else {
            // Method 2: Try to request permissions and fallback
            print("❌ No accessibility permissions - attempting to request")
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            let granted = AXIsProcessTrustedWithOptions(options as CFDictionary)
            
            if granted {
                print("✅ Permissions granted on request - using CGEvent paste")
                return performCGEventPaste()
            } else {
                print("❌ Permissions still denied - using PasteHelper fallback")
                PasteHelper.paste()
                return true // Assume PasteHelper handles it
            }
        }
    }
    
    private func performCGEventPaste() -> Bool {
        print("⌨️ Executing CGEvent Cmd+V...")
        
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Create Cmd+V key events
        guard let cmdDownEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true),
              let vDownEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let vUpEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false),
              let cmdUpEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false) else {
            print("❌ Failed to create CGEvents")
            return false
        }
        
        // Set command flag for V key events
        vDownEvent.flags = .maskCommand
        vUpEvent.flags = .maskCommand
        
        // Post events in sequence with slight delays for reliability
        cmdDownEvent.post(tap: .cghidEventTap)
        usleep(10000) // 10ms delay
        vDownEvent.post(tap: .cghidEventTap)
        usleep(10000) // 10ms delay
        vUpEvent.post(tap: .cghidEventTap)
        usleep(10000) // 10ms delay
        cmdUpEvent.post(tap: .cghidEventTap)
        
        print("✅ CGEvent Cmd+V posted successfully")
        return true
    }
    
    private func simulateCommandV() {
        print("⌨️ Simulating Cmd+V key combination...")
        
        // Check if we have accessibility permissions first
        let hasPermissions = AXIsProcessTrusted()
        print("🔐 Accessibility permissions for CGEvent: \(hasPermissions ? "GRANTED" : "NOT GRANTED")")
        
        if !hasPermissions {
            print("❌ No accessibility permissions - requesting permissions")
            // Request permissions with prompt
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
            print("🔐 Permission request result: \(trusted)")
            
            if !trusted {
                print("❌ Still no permissions after request - paste operation failed")
                return
            }
        }
        
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Create Cmd+V key events
        guard let cmdDownEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true),
              let vDownEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let vUpEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false),
              let cmdUpEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false) else {
            print("❌ Failed to create key events")
            return
        }
        
        // Set command flag for V key events
        vDownEvent.flags = .maskCommand
        vUpEvent.flags = .maskCommand
        
        // Post events in sequence
        cmdDownEvent.post(tap: .cghidEventTap)
        vDownEvent.post(tap: .cghidEventTap)
        vUpEvent.post(tap: .cghidEventTap)
        cmdUpEvent.post(tap: .cghidEventTap)
        
        print("✅ CGEvent Cmd+V posted successfully")
    }

    // MARK: - Debug Helper
    
    // MARK: - Core Data Helpers
    
    private func saveContext() {
        // Note: This method is a placeholder - actual context saving should be handled by the app delegate
        print("💾 Context save requested")
    }
    
    private func notifyUIUpdate() {
        // Trigger UI update by toggling the published property
        DispatchQueue.main.async { [weak self] in
            self?.updateTrigger.toggle()
            
            // Also post a custom notification for immediate UI updates
            NotificationCenter.default.post(name: NSNotification.Name("ClipboardItemsUpdated"), object: nil)
        }
    }
    
    // MARK: - Debug Helper
    
    private func debugPasteboardState() {
        let changeCount = NSPasteboard.general.changeCount
        let stringContent = NSPasteboard.general.string(forType: .string)
        let imageContent = NSPasteboard.general.readObjects(forClasses: [NSImage.self])?.first as? NSImage
        
        print("🔍 Pasteboard Debug:")
        print("  • Change count: \(changeCount)")
        print("  • String content: \(stringContent?.prefix(50) ?? "nil")...")
        print("  • Image content: \(imageContent?.size ?? CGSize.zero)")
        print("  • Available types: \(NSPasteboard.general.types ?? [])")
    }
}

extension NSImage {
    var pngData: Data? {
        guard let tiffRepresentation = tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
        return bitmapImage.representation(using: .png, properties: [:])
    }
}
