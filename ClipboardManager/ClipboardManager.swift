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

    private let viewContext = PersistenceController.shared.container.viewContext
    
    // Image processing constants - based on Clipy/Maccy patterns
    private let maxImageSize: CGFloat = 1024 // Maximum dimension for stored images
    private let thumbnailSize: CGFloat = 200 // Thumbnail size for UI
    
    // Performance optimization: Skip monitoring when we're doing internal paste operations
    private var isInternalPasteOperation = false
    private let pasteOperationQueue = DispatchQueue(label: "paste-operations", qos: .userInteractive)

    init() {
        self.lastChangeCount = pasteboard.changeCount
        // Request accessibility permissions at startup like Clipy/Maccy
        checkAndRequestAccessibilityPermissions()
        startMonitoring()
    }
    
    // MARK: - Accessibility Permissions (Clipy/Maccy pattern)
    
    private func checkAndRequestAccessibilityPermissions() {
        print("🔐 Checking accessibility permissions at startup...")
        
        // Check if accessibility is enabled
        let accessEnabled = AXIsProcessTrusted()
        
        if !accessEnabled {
            print("❌ Accessibility permissions not granted - requesting...")
            // Request permissions like Maccy does
            let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
            let options = [checkOptPrompt: true]
            let _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
            
            // Show alert to user
            showAccessibilityAlert()
        } else {
            print("✅ Accessibility permissions already granted")
        }
    }
    
    private func showAccessibilityAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Required"
            alert.informativeText = "ClipboardManager needs accessibility permissions to paste items automatically. Please grant permissions in System Preferences > Security & Privacy > Privacy > Accessibility."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Open System Preferences")
            
            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
                // Open System Preferences
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        }
    }

    func startMonitoring() {
        print("Starting clipboard monitoring...")
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
    }

    func stopMonitoring() {
        print("Stopping clipboard monitoring.")
        timer?.invalidate()
        timer = nil
    }

    private func checkPasteboard() {
        guard pasteboard.changeCount != lastChangeCount else {
            return
        }
        
        // Skip monitoring during internal paste operations to prevent duplicates
        guard !isInternalPasteOperation else {
            lastChangeCount = pasteboard.changeCount
            return
        }
        
        print("Pasteboard change detected. Change count: \(pasteboard.changeCount)")
        lastChangeCount = pasteboard.changeCount

        if let items = pasteboard.pasteboardItems {
            for item in items {
                // Check for image data first (screenshots, images)
                if let imageData = item.data(forType: .tiff) ?? item.data(forType: .png) {
                    print("Found image data.")
                    // Process image asynchronously to prevent crashes
                    processImageData(imageData)
                } else if let string = item.string(forType: .string) {
                    print("Found string content: \(string.prefix(50))...")
                    addItem(content: string)
                }
            }
        }
    }
    
    private func processImageData(_ imageData: Data) {
        // Process image on background queue to prevent UI blocking
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Use autoreleasepool to manage memory efficiently
            autoreleasepool {
                // Quick size check to avoid processing extremely large images
                guard imageData.count < 50_000_000 else { // 50MB limit
                    print("Image too large, skipping: \(imageData.count) bytes")
                    return
                }
                
                // Create image with memory-efficient approach
                guard let image = NSImage(data: imageData) else {
                    print("Failed to create NSImage from data")
                    return
                }
                
                // Early exit if image is too large
                let originalSize = image.size
                guard originalSize.width > 0 && originalSize.height > 0 else {
                    print("Invalid image dimensions")
                    return
                }
                
                // Resize image to prevent memory issues - use smaller max size for better performance
                let resizedImage = image.resized(to: min(self.maxImageSize, 800))
                
                // Store the resized image
                self.addItem(image: resizedImage)
            }
        }
    }

    private func addItem(content: String? = nil, image: NSImage? = nil) {
        print("Adding new item to Core Data with encryption.")
        
        // Ensure we're on the main thread for Core Data operations
        DispatchQueue.main.async {
            let newItem = ClipboardItem(context: self.viewContext)
            newItem.id = UUID()
            newItem.createdAt = Date()
            newItem.sourceApp = NSWorkspace.shared.frontmostApplication?.localizedName

            if let content = content {
                // Use encrypted content instead of plaintext
                newItem.decryptedContent = content
                newItem.category = "Text"
                self.saveContext()
                self.notifyUIUpdate()
            }

            if let image = image {
                // Store the resized image in PNG format for better compatibility
                if let pngData = image.pngRepresentation {
                    // Use encrypted image data instead of plaintext
                    newItem.decryptedImageData = pngData
                } else if let tiffData = image.tiffRepresentation {
                    // Use encrypted image data instead of plaintext
                    newItem.decryptedImageData = tiffData
                }
                
                newItem.category = "Image"
                
                // Skip OCR for now to improve performance - can be enabled later if needed
                // Extract text from image using OCR (use thumbnail for OCR to save memory)
                // let imageForOCR = thumbnail ?? image
                // self.extractText(from: imageForOCR) { text in
                //     DispatchQueue.main.async {
                //         if let text = text, !text.isEmpty {
                //             print("Extracted OCR text: \(text.prefix(50))...")
                //             newItem.decryptedContent = text
                //         }
                //         self.saveContext()
                //         self.notifyUIUpdate()
                //     }
                // }
                
                self.saveContext()
                self.notifyUIUpdate()
            }
            
            self.cullHistory()
        }
    }
    
    private func cullHistory() {
        let maxHistory = UserDefaults.standard.integer(forKey: "maxHistorySize")
        if maxHistory == 0 { return } // 0 means unlimited

        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = ClipboardItem.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItem.createdAt, ascending: true)]
        
        do {
            let items = try viewContext.fetch(fetchRequest) as! [ClipboardItem]
            if items.count > maxHistory {
                let itemsToDelete = items.prefix(items.count - maxHistory)
                for item in itemsToDelete {
                    viewContext.delete(item)
                }
                saveContext()
            }
        } catch {
            print("Error culling history: \(error)")
        }
    }
    
    private func extractText(from image: NSImage, completion: @escaping (String?) -> Void) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion(nil)
            return
        }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation],
                  error == nil else {
                completion(nil)
                return
            }
            let text = observations.compactMap {
                $0.topCandidates(1).first?.string
            }.joined(separator: "\n")
            completion(text)
        }
        
        do {
            try requestHandler.perform([request])
        } catch {
            print("Error performing text recognition: \(error)")
            completion(nil)
        }
    }

    func copyToPasteboard(item: ClipboardItem) {
        print("📋 Copying item to pasteboard...")
        print("📋 Item ID: \(item.id?.uuidString ?? "nil")")
        
        // Clear pasteboard first for clean state
        pasteboard.clearContents()
        
        // Determine what type of content we have using decrypted data
        let hasTextContent = item.decryptedContent != nil && !item.decryptedContent!.isEmpty
        let hasImageData = item.decryptedImageData != nil
        
        print("📋 Content analysis:")
        print("   • Has text content: \(hasTextContent)")
        print("   • Has image data: \(hasImageData)")
        if hasTextContent {
            print("   • Text content length: \(item.decryptedContent?.count ?? 0)")
        }
        if hasImageData {
            print("   • Image data size: \(item.decryptedImageData?.count ?? 0) bytes")
        }
        
        // Handle image data first (priority for mixed content)
        if hasImageData {
            if let imageData = item.decryptedImageData, let image = NSImage(data: imageData) {
                print("📋 Processing image data (\(imageData.count) bytes)")
                print("📋 Image size: \(image.size)")
                
                // Use writeObjects for better image handling (supports multiple formats)
                let success = pasteboard.writeObjects([image])
                
                if success {
                    print("📋 Image written to pasteboard using writeObjects")
                } else {
                    print("❌ Failed to write image using writeObjects, trying fallback methods")
                    
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
                    print("❌ Image verification failed")
                }
            } else {
                print("❌ Could not create NSImage from image data")
                if let imageData = item.decryptedImageData {
                    print("❌ Image data size: \(imageData.count) bytes")
                    print("❌ Image data first 16 bytes: \(imageData.prefix(16).map { String(format: "%02x", $0) }.joined(separator: " "))")
                }
            }
        }
        // Handle text content only if no image data
        else if hasTextContent {
            let content = item.decryptedContent!
            
            print("📋 Processing text content (\(content.count) characters)")
            
            // Use declareTypes first for better compatibility (Clipy pattern)
            pasteboard.declareTypes([.string], owner: nil)
            let success = pasteboard.setString(content, forType: .string)
            
            if success {
                print("📋 Text written to pasteboard: \(content.prefix(50))...")
            } else {
                print("❌ Failed to write text to pasteboard")
            }
            
            // Verify the content was written correctly
            if let pasteboardContent = pasteboard.string(forType: .string) {
                print("✅ Pasteboard verification: \(pasteboardContent.prefix(50))...")
            } else {
                print("❌ Pasteboard verification failed")
            }
        }
        
        // Force pasteboard synchronization (important for programmatic paste)
        // Note: synchronize() was removed in newer macOS versions, but the pasteboard
        // is automatically synchronized when we set data
        let changeCount = pasteboard.changeCount
        print("📋 Pasteboard change count: \(changeCount)")
        
        if hasImageData {
            print("✅ Image item copied to pasteboard")
        } else {
            print("✅ Text item copied to pasteboard: \(item.content?.prefix(50) ?? "empty")")
        }
    }

    // MARK: - Paste Operations (Based on Clipy/Maccy implementations)
    
    func performPasteOperation(item: ClipboardItem, completion: @escaping (Bool) -> Void) {
        print("🚀 Starting paste operation for item: \(item.content?.prefix(30) ?? "Image")")
        
        // Check initial hotkeys state
        print("🔍 Hotkeys state check before paste operation:")
        let carbonManager = HotkeysManager.shared
        let appDelegate = NSApp.delegate as? AppDelegate
        print("  • Carbon hotkeys are \(carbonManager.isEnabled ? "enabled" : "disabled")")
        print("  • Edge window is \(appDelegate?.isEdgeWindowShown == true ? "shown" : "hidden")")
        
        // Notify that paste operation is starting
        print("📢 Sending disable notifications for hotkeys")
        NotificationCenter.default.post(name: .pasteOperationStart, object: nil, userInfo: nil)
        NotificationCenter.default.post(name: .disableGlobalHotkeys, object: nil, userInfo: nil)
        
        // Verify hotkeys were disabled
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            print("🔍 Hotkeys state check after disable notification:")
            print("  • Carbon hotkeys are \(carbonManager.isEnabled ? "enabled" : "disabled")")
        }
        
        // Debug: Print current pasteboard state
        debugPasteboardState()
        
        // Set flag to prevent monitoring during paste
        isInternalPasteOperation = true
        
        // Always copy to pasteboard first
        copyToPasteboard(item: item)
        
        // Debug: Print pasteboard state after copying
        print("📋 After copyToPasteboard:")
        debugPasteboardState()
        
        // Check accessibility permissions for programmatic pasting
        if AXIsProcessTrusted() {
            print("✅ Accessibility permissions available - using programmatic paste")
            
            // Longer delay to ensure pasteboard is properly updated and app is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                let pasteSuccess = self.performProgrammaticPaste()
                
                // Reset flag after operation with proper timing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.isInternalPasteOperation = false
                    
                    // Notify that paste operation is ending - delay to ensure coordination
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        print("📢 Sending pasteOperationEnd notification")
                        NotificationCenter.default.post(name: .pasteOperationEnd, object: nil, userInfo: nil)
                        
                        // Re-enable HotkeysManager after GlobalShortcutsManager is ready
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            print("📢 Sending enableGlobalHotkeys notification")
                            NotificationCenter.default.post(name: .enableGlobalHotkeys, object: nil, userInfo: nil)
                            
                            // Verify hotkeys were re-enabled
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                let carbonManager = HotkeysManager.shared
                                print("🔍 Hotkeys state check after re-enable:")
                                print("  • Carbon hotkeys are \(carbonManager.isEnabled ? "enabled" : "disabled")")
                            }
                        }
                    }
                }
                
                completion(pasteSuccess)
            }
        } else {
            print("❌ No accessibility permissions - using manual paste mode")
            
            // Reset flag after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.isInternalPasteOperation = false
                
                // Notify that paste operation is ending - delay to ensure coordination
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    print("📢 Sending pasteOperationEnd notification")
                    NotificationCenter.default.post(name: .pasteOperationEnd, object: nil, userInfo: nil)
                    
                    // Re-enable HotkeysManager after GlobalShortcutsManager is ready
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        print("📢 Sending enableGlobalHotkeys notification")
                        NotificationCenter.default.post(name: .enableGlobalHotkeys, object: nil, userInfo: nil)
                        
                        // Verify hotkeys were re-enabled
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            let carbonManager = HotkeysManager.shared
                            print("🔍 Hotkeys state check after re-enable:")
                            print("  • Carbon hotkeys are \(carbonManager.isEnabled ? "enabled" : "disabled")")
                        }
                    }
                }
            }
            
            print("✅ Item copied to pasteboard - ready for manual paste with Cmd+V")
            completion(true)
        }
    }
    
    private func performProgrammaticPaste() -> Bool {
        print("🤖 Performing programmatic paste using improved Clipy/Maccy pattern...")
        
        // Ensure we're on the main thread
        guard Thread.isMainThread else {
            print("❌ performProgrammaticPaste must be called on main thread")
            return false
        }
        
        // Additional check: ensure accessibility is still enabled
        guard AXIsProcessTrusted() else {
            print("❌ Accessibility permissions lost during paste operation")
            return false
        }
        
        // Give the system a moment to process the pasteboard change
        Thread.sleep(forTimeInterval: 0.05)
        
        // Get the V key code using the same method as Maccy
        let vKeyCode: CGKeyCode = 0x09 // V key - this is correct
        
        // Create event source (same as Maccy)
        let source = CGEventSource(stateID: .combinedSessionState)
        
        // Set up event filtering like Clipy does
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        
        // Create events with proper error handling
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            print("❌ Failed to create CGEvents")
            return false
        }
        
        // Set command modifier flags (Cmd+V) - critical for paste
        let commandFlag = CGEventFlags.maskCommand
        keyDown.flags = commandFlag
        keyUp.flags = commandFlag
        
        // Verify the events were created correctly
        print("📝 Created CGEvents - KeyDown: \(keyDown), KeyUp: \(keyUp)")
        print("📝 Command flags set: \(commandFlag)")
        
        // Post events using cgSessionEventTap (Maccy pattern)
        print("📤 Posting events with cgSessionEventTap...")
        keyDown.post(tap: .cgSessionEventTap)
        
        // Small delay between key down and key up (more reliable)
        usleep(1000) // 1ms delay
        
        keyUp.post(tap: .cgSessionEventTap)
        
        print("✅ Programmatic paste events posted successfully")
        return true
    }
    
    // MARK: - Existing Methods

    private func saveContext() {
        do {
            try viewContext.save()
            print("Context saved successfully")
            
            // Post notification that context was saved
            NotificationCenter.default.post(name: .NSManagedObjectContextDidSave, object: viewContext)
        } catch {
            let nsError = error as NSError
            print("Failed to save context: \(nsError), \(nsError.userInfo)")
        }
    }
    
    private func notifyUIUpdate() {
        // Trigger UI update by toggling the published property
        DispatchQueue.main.async {
            self.updateTrigger.toggle()
            
            // Also post a custom notification for immediate UI updates
            NotificationCenter.default.post(name: NSNotification.Name("ClipboardItemAdded"), object: nil)
        }
    }
}

extension NSImage {
    var pngRepresentation: Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
    
    func resized(to maxSize: CGFloat) -> NSImage {
        let originalSize = self.size
        
        // If image is already smaller than max size, return as-is
        if originalSize.width <= maxSize && originalSize.height <= maxSize {
            return self
        }
        
        // Calculate new size maintaining aspect ratio
        let scale = min(maxSize / originalSize.width, maxSize / originalSize.height)
        let newSize = NSSize(width: originalSize.width * scale, height: originalSize.height * scale)
        
        // Use more efficient image context for better performance
        let newImage = NSImage(size: newSize)
        newImage.cacheMode = .never // Prevent unnecessary caching
        
        newImage.lockFocus()
        defer { newImage.unlockFocus() }
        
        // Use high-quality interpolation for better results
        let context = NSGraphicsContext.current
        context?.imageInterpolation = .high
        
        // Draw original image scaled to new size
        let rect = NSRect(origin: .zero, size: newSize)
        self.draw(in: rect, from: NSRect(origin: .zero, size: originalSize), operation: .copy, fraction: 1.0)
        
        return newImage
    }
    
    // Create thumbnail with fixed size for consistent UI - optimized version
    func thumbnail(size: CGFloat) -> NSImage {
        let thumbnailSize = NSSize(width: size, height: size)
        let thumbnail = NSImage(size: thumbnailSize)
        thumbnail.cacheMode = .never
        
        thumbnail.lockFocus()
        defer { thumbnail.unlockFocus() }
        
        // Set high-quality rendering
        let context = NSGraphicsContext.current
        context?.imageInterpolation = .high
        context?.shouldAntialias = true
        
        // Calculate the rect to draw the image centered and scaled
        let imageSize = self.size
        let scale = min(size / imageSize.width, size / imageSize.height)
        let scaledSize = NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
        
        let x = (size - scaledSize.width) / 2
        let y = (size - scaledSize.height) / 2
        let rect = NSRect(x: x, y: y, width: scaledSize.width, height: scaledSize.height)
        
        self.draw(in: rect, from: NSRect(origin: .zero, size: imageSize), operation: .copy, fraction: 1.0)
        
        return thumbnail
    }
}

extension ClipboardManager {
    private func debugPasteboardState() {
        print("📋 === PASTEBOARD DEBUG STATE ===")
        let pasteboard = NSPasteboard.general
        print("📋 Change count: \(pasteboard.changeCount)")
        print("📋 Available types: \(pasteboard.types?.map { $0.rawValue } ?? ["none"])")
        
        if let string = pasteboard.string(forType: .string) {
            print("📋 String content: '\(string)'")
            print("📋 String length: \(string.count)")
            print("📋 String isEmpty: \(string.isEmpty)")
        } else {
            print("📋 No string content found")
        }
        print("📋 === END PASTEBOARD DEBUG ===")
    }
}

// Global variable to provide access to ClipboardManager instance, avoiding module name conflicts
let clipboardManagerInstance = ClipboardManager.shared