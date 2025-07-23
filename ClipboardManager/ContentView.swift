import SwiftUI
import CoreData
import Foundation
import AppKit
import Carbon

// MARK: - Constants
private enum KeyCode {
    static let downArrow = 125
    static let upArrow = 126
    static let returnKey = 36
    static let escape = 53
}

private enum Timing {
    static let shortDelay = 0.1
    static let mediumDelay = 0.2
}

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject private var clipboardManager = clipboardManagerInstance
    @StateObject private var keyboardMonitor = KeyboardMonitor()
    @StateObject private var searchManager = SearchManager()
    @StateObject private var folderManager: FolderManager
    @StateObject private var bulkActionsManager: BulkActionsManager
    @StateObject private var customActionsManager = CustomActionsManager()
    @StateObject private var contentFilterManager = ContentFilterManager()
    @AppStorage("sidebarPosition") private var sidebarPosition = "right"
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ClipboardItem.createdAt, ascending: false)],
        animation: .default
    )
    private var items: FetchedResults<ClipboardItem>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Folder.name, ascending: true)]
    )
    private var folders: FetchedResults<Folder>

    @State private var selectedFolder: Folder?
    @State private var selectedItem: ClipboardItem?
    @State private var selectedIndex = 0
    @State private var refreshID = UUID()
    @State private var scrollResetTrigger = UUID()
    @State private var selectedSourceApp: String?
    @State private var showSourceFilter = false
    @State private var showAdvancedSearch = false
    @State private var showContentFilters = false
    @State private var searchText = ""
    @AppStorage("showFolderSidebar") private var showFolderSidebar = false
    
    init() {
        let context = PersistenceController.shared.container.viewContext
        _folderManager = StateObject(wrappedValue: FolderManager(viewContext: context))
        _bulkActionsManager = StateObject(wrappedValue: BulkActionsManager(viewContext: context))
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Conditional sidebar on the left
                if showFolderSidebar {
                    FolderSidebarView(folderManager: folderManager)
                        .transition(.move(edge: .leading))
                }
                
                // Main content area
                VStack(spacing: 0) {
                    // Header
                    HeaderView(
                        onToggleSidebar: {
                            showFolderSidebar.toggle()
                        },
                        isSidebarVisible: showFolderSidebar
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .background(Color.gray.opacity(0.05))
                    
                    // Search
                    SearchView(searchText: $searchManager.searchText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.05))
                    
                    // Folder title if one is selected
                    if showFolderSidebar && folderManager.selectedFolder != nil {
                        HStack {
                            Text("Folder: \(folderManager.selectedFolder?.name ?? "Unknown")")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button(action: {
                                folderManager.selectedFolder = nil
                            }) {
                                Text("Show All")
                                    .font(.system(size: 11))
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .background(Color(NSColor.controlBackgroundColor))
                    }
                    
                    // Content
                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                // Invisible anchor at the top for reliable scrolling
                                Color.clear.frame(height: 0).id("top")
                                
                                ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                                    EnhancedClipboardCard(
                                        item: item,
                                        isSelected: bulkActionsManager.isSelectionMode ? bulkActionsManager.selectedItems.contains(item) : (index == selectedIndex),
                                        selectionIndex: index,
                                        onToggleFavorite: {
                                            item.isFavorite.toggle()
                                            do {
                                                try viewContext.save()
                                            } catch {
                                                debugLog("Failed to save favorite status: \(error.localizedDescription)")
                                                // Revert the change if save failed
                                                item.isFavorite.toggle()
                                            }
                                        },
                                        onCopyToClipboard: {
                                            // Close sidebar when copying to clipboard - FIRST
                                            let wasSidebarOpen = showFolderSidebar
                                            if wasSidebarOpen {
                                                showFolderSidebar = false
                                            }
                                            
                                            // Only copy to clipboard, don't paste (Copy button should only copy)
                                            clipboardManagerInstance.copyToPasteboard(item: item)
                                        },
                                        onDeleteItem: {
                                            deleteItems(offsets: IndexSet([index]))
                                        },
                                        onToggleSelection: {
                                            if bulkActionsManager.isSelectionMode {
                                                bulkActionsManager.toggleSelection(for: item)
                                            } else {
                                                handleItemSelection(item: item, index: index)
                                            }
                                        },
                                        onViewSource: {
                                            // Handle view source
                                        },
                                        onUndo: {
                                            // Handle undo
                                        },
                                        onEditText: {
                                            // Handle edit text
                                        }
                                    )
                                    .id(item.id)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        .background(Color.gray.opacity(0.05))
                        .id(scrollResetTrigger)
                        .onAppear {
                            // Auto-scroll to top and highlight first item when view appears
                            scrollToTopAndHighlightFirst(scrollProxy: scrollProxy)
                        }
                        .onChange(of: filteredItems) { _ in
                            // Auto-scroll to top when items change (e.g., search, filter)
                            scrollToTopAndHighlightFirst(scrollProxy: scrollProxy)
                        }
                        .onChange(of: items.count) { _ in
                            // Handle new items being added (dynamic updates)
                            if showFolderSidebar {
                                handleNewItemAdded(scrollProxy: scrollProxy)
                            }
                        }
                        .onChange(of: folderManager.selectedFolder) { _ in
                            // Auto-scroll to top when folder selection changes
                            scrollToTopAndHighlightFirst(scrollProxy: scrollProxy)
                        }
                        .onChange(of: showFolderSidebar) { isVisible in
                            if isVisible {
                                // Reset sidebar state when opened (ensures clean state every time)
                                resetSidebarState()
                                
                                // Ensure window has focus for keyboard events
                                DispatchQueue.main.async {
                                    if let window = NSApp.keyWindow ?? NSApp.mainWindow {
                                        window.makeKeyAndOrderFront(nil)
                                    }
                                }
                                
                                // Auto-scroll to top when sidebar is opened
                                // Use a delay to ensure the sidebar is fully rendered
                                DispatchQueue.main.asyncAfter(deadline: .now() + Timing.mediumDelay) {
                                    scrollToTopAndHighlightFirst(scrollProxy: scrollProxy)
                                }
                            } else {
                                // Also reset sidebar state when closed (double insurance)
                                resetSidebarState()
                            }
                        }
                        .onReceive(keyboardMonitor.$keyPressed) { keyPressed in
                            if let (key, isPressed) = keyPressed, isPressed {
                                handleKeyPress(key, scrollProxy: scrollProxy)
                            }
                        }
                    }
                    
                    // Pinned Items Section
                    PinnedItemsSection(
                        pinnedItems: pinnedItems,
                        onUnpinItem: { item in
                            item.isPinned = false
                            item.pinnedTimestamp = nil
                            do {
                                try viewContext.save()
                            } catch {
                                debugLog("Failed to unpin item: \(error.localizedDescription)")
                                // Revert the change if save failed
                                item.isPinned = true
                                item.pinnedTimestamp = Date()
                            }
                        },
                        onPasteItem: { item in
                            PasteHelper.log("🔄 PinnedItemsSection onPasteItem triggered", level: .info)
                            
                            // Close sidebar when pasting - FIRST
                            let wasSidebarOpen = showFolderSidebar
                            if wasSidebarOpen {
                                showFolderSidebar = false
                            }
                            
                            // Use the proper paste operation (same as Enter key)
                            DispatchQueue.main.asyncAfter(deadline: .now() + Timing.mediumDelay) {
                                PasteHelper.log("🚀 PinnedItemsSection triggering performPasteOperation", level: .info)
                                clipboardManager.performPasteOperation(item: item) { success in
                                    PasteHelper.log("📝 PinnedItemsSection paste callback - Success: \(success)", level: .info)
                                }
                            }
                        }
                    )
                    
                    // Footer
                    if !filteredItems.isEmpty {
                        FooterView(
                            itemCount: filteredItems.count,
                            onSettingsPressed: {
                                if let appDelegate = NSApp.delegate as? AppDelegate {
                                    appDelegate.openSettings(nil)
                                }
                            },
                            onOrganizePressed: {
                                if let appDelegate = NSApp.delegate as? AppDelegate {
                                    appDelegate.openOrganizationWindow(nil)
                                }
                            },
                            onClearPressed: { clearAllItems() }
                        )
                        .background(Color(NSColor.controlBackgroundColor))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .animation(.easeInOut(duration: 0.2), value: showFolderSidebar)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            setupInitialState()
            
            // Add notification observer for closing sidebar
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("CloseFolderSidebar"),
                object: nil,
                queue: .main
            ) { _ in
                if self.showFolderSidebar {
                    self.showFolderSidebar = false
                }
            }
        }
        .onDisappear {
            // Remove notification observer
            NotificationCenter.default.removeObserver(
                self,
                name: NSNotification.Name("CloseFolderSidebar"),
                object: nil
            )
        }
        .onReceive(clipboardManager.$updateTrigger) { _ in
            refreshView()
        }
        .onChange(of: filteredItems) { newItems in
            resetSelection(for: newItems)
        }
    }
    
    private var sourceApps: [String] {
        let apps = Set(items.compactMap { $0.sourceApp })
        return Array(apps).sorted()
    }
    
    private var filteredItems: [ClipboardItem] {
        var filtered = Array(items)
        
        // Apply content filtering
        filtered = filtered.filter { item in
            !contentFilterManager.shouldIgnoreItem(item)
        }
        
        // Apply folder filtering
        if let selectedFolder = folderManager.selectedFolder {
            filtered = filtered.filter { $0.folder == selectedFolder }
        }
        
        // Apply search manager filters
        if !searchManager.searchText.isEmpty {
            filtered = searchManager.fuzzySearch(items: filtered)
        }
        
        // Apply type filter
        filtered = searchManager.filterByType(items: filtered)
        
        // Apply date filter
        filtered = searchManager.filterByDate(items: filtered)
        
        // Apply source app filter
        if let selectedSourceApp = selectedSourceApp {
            filtered = filtered.filter { $0.sourceApp == selectedSourceApp }
        }
        
        return filtered
    }
    
    private var pinnedItems: [ClipboardItem] {
        return Array(items).filter { $0.isPinned }.sorted { 
            guard let timestamp1 = $0.pinnedTimestamp, let timestamp2 = $1.pinnedTimestamp else {
                return $0.pinnedTimestamp != nil // Items with timestamps come first
            }
            return timestamp1 > timestamp2 // Sort by pin time, newest first
        }
    }
    
    private func scrollToTopAndHighlightFirst(scrollProxy: ScrollViewProxy) {
        // Guard against empty list to prevent crashes
        guard !filteredItems.isEmpty else {
            selectedIndex = 0
            selectedItem = nil
            return
        }
        
        // Reset to first item (newest item since sorted by createdAt descending)
        selectedIndex = 0
        
        // Update selected item to first item
        let firstItem = filteredItems[0]
        selectedItem = firstItem
        
        // Ensure the first item has a valid ID
        guard let firstItemId = firstItem.id else {
            debugLog("First item has no ID, scrolling to top anchor")
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.3)) {
                    scrollProxy.scrollTo("top", anchor: .top)
                }
            }
            return
        }
        
        // Use delayed execution to ensure view is fully rendered
        // This handles timing issues mentioned in the guide
        DispatchQueue.main.asyncAfter(deadline: .now() + Timing.shortDelay) {
            withAnimation(.easeInOut(duration: 0.3)) {
                scrollProxy.scrollTo(firstItemId, anchor: .top)
            }
        }
    }
    
    /// Handle dynamic updates when new items are added
    /// This ensures the sidebar stays up-to-date with latest items
    private func handleNewItemAdded(scrollProxy: ScrollViewProxy) {
        // Only auto-scroll if sidebar is open and we have items
        guard showFolderSidebar && !filteredItems.isEmpty else { return }
        
        // Re-apply scroll and highlight to show the newest item
        scrollToTopAndHighlightFirst(scrollProxy: scrollProxy)
    }
    
    private func setupInitialState() {
        selectedIndex = 0
        if let firstItem = filteredItems.first {
            selectedItem = firstItem
        }
        keyboardMonitor.startMonitoring()
    }
    
    private func resetSidebarState() {
        // Reset search state
        searchManager.searchText = ""
        searchManager.selectedSearchType = .all
        searchManager.dateRange = .all
        searchManager.showAdvancedFilters = false
        
        // Reset bulk actions
        bulkActionsManager.isSelectionMode = false
        bulkActionsManager.selectedItems.removeAll()
        bulkActionsManager.showBulkActions = false
        
        // Set initial state (following guide recommendations)
        selectedFolder = nil
        selectedItem = nil
        selectedIndex = 0
        
        // Reset to highlight the newest item if items exist
        // This ensures we always start with the latest item highlighted
        if !filteredItems.isEmpty {
            selectedItem = filteredItems[0]
            selectedIndex = 0
        }
        
        // Reset scroll position
        scrollResetTrigger = UUID()
    }
    
    // MARK: - Shared Logic
    
    private func closeSidebarAndWindow() {
        // Close sidebar when pasting - FIRST, before closing window
        let wasSidebarOpen = showFolderSidebar
        if wasSidebarOpen {
            showFolderSidebar = false
        }
        
        // Ensure hotkeys are reloaded when window is closed - do this IMMEDIATELY
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            DispatchQueue.main.async { // Use async instead of asyncAfter for immediate execution
                appDelegate.registerHotkeys()
            }
        }
        
        // Close edge window after sidebar state change
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            window.close()
        } else {
            debugLog("No key or main window found to close")
        }
    }
    
    #if DEBUG
    private func debugLog(_ message: String) {
        print("📊 [ClipboardManager] \(message)")
    }
    #else
    private func debugLog(_ message: String) { }
    #endif
    
    private func handleItemSelection(item: ClipboardItem, index: Int) {
        selectedItem = item
        selectedIndex = index
        
        // Close sidebar and window using shared logic
        closeSidebarAndWindow()
        
        // Copy to clipboard and paste
        DispatchQueue.main.asyncAfter(deadline: .now() + Timing.mediumDelay) {
            clipboardManager.performPasteOperation(item: item) { success in
                // Logging removed for performance
            }
        }
    }
    
    private func handleKeyPress(_ keyPressed: String, scrollProxy: ScrollViewProxy) {
        switch keyPressed {
        case "down":
            if !filteredItems.isEmpty {
                let newIndex = min(selectedIndex + 1, filteredItems.count - 1)
                selectedIndex = newIndex
                selectedItem = filteredItems[newIndex]
                // Auto-scroll to the newly selected item
                scrollToSelectedItem(proxy: scrollProxy, index: newIndex)
            }
        case "up":
            if !filteredItems.isEmpty {
                let newIndex = max(selectedIndex - 1, 0)
                selectedIndex = newIndex
                selectedItem = filteredItems[newIndex]
                // Auto-scroll to the newly selected item
                scrollToSelectedItem(proxy: scrollProxy, index: newIndex)
            }
        case "return":
            handleEnterKey()
        case "escape":
            // Close sidebar and window using shared logic
            closeSidebarAndWindow()
        default:
            break
        }
    }
    
    private func handleEnterKey() {
        PasteHelper.log("🔑 ENTER key handler triggered in ContentView", level: .info)
        
        guard !filteredItems.isEmpty && selectedIndex < filteredItems.count else { 
            PasteHelper.log("❌ Enter key pressed but no valid selection. Items: \(filteredItems.count), SelectedIndex: \(selectedIndex)", level: .warning)
            return 
        }
        
        let item = filteredItems[selectedIndex]
        selectedItem = item
        
        PasteHelper.log("📋 Selected item for paste: \(item.content?.prefix(30) ?? "Image") at index \(selectedIndex)", level: .info)
        
        // Close sidebar and window using shared logic
        PasteHelper.log("🚪 Closing sidebar and window", level: .debug)
        closeSidebarAndWindow()
        
        // NEW FLOW: First restore focus, then paste (with faster timing)
        DispatchQueue.main.asyncAfter(deadline: .now() + Timing.mediumDelay) {
            PasteHelper.log("🔄 Starting focus restoration BEFORE paste", level: .info)
            
            // Restore focus first
            PasteHelper.restorePreviousAppFocus()
            
            // Wait for focus restoration to complete, then paste (reduced delay)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                PasteHelper.log("🚀 Triggering paste operation after focus restoration", level: .info)
                clipboardManager.performPasteOperation(item: item) { success in
                    PasteHelper.log("📝 Paste operation callback - Success: \(success)", level: .info)
                    
                    if !success {
                        PasteHelper.log("❌ Paste failed", level: .warning)
                    }
                    // Note: No cursor restoration - let paste happen at current cursor position
                }
            }
        }
    }
    
    private func refreshView() {
        // Reset to first item (following guide recommendations)
        selectedIndex = 0
        
        // Always update to the newest item (first item in sorted list)
        if !filteredItems.isEmpty {
            selectedItem = filteredItems[0]
        } else {
            selectedItem = nil
        }
        
        refreshID = UUID()
    }
    
    private func resetSelection(for newItems: [ClipboardItem]) {
        // Reset to first item (newest item since sorted by createdAt descending)
        selectedIndex = 0
        
        // Select the newest item
        if !newItems.isEmpty {
            selectedItem = newItems[0]
        } else {
            selectedItem = nil
        }
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            debugLog("Failed to save context: \(error.localizedDescription)")
            // Handle the error appropriately - could show user notification
        }
    }
    
    private func createNewFolder(for item: ClipboardItem) {
        let newFolder = Folder(context: viewContext)
        newFolder.id = UUID()
        newFolder.name = "New Folder"
        newFolder.createdAt = Date()
        
        item.folder = newFolder
        saveContext()
    }
    
    private func clearAllItems() {
        let fetchRequest: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        
        do {
            let allItems = try viewContext.fetch(fetchRequest)
            for item in allItems {
                viewContext.delete(item)
            }
            try viewContext.save()
            
            // Reset selection
            selectedIndex = 0
            selectedItem = nil
            
        } catch {
            debugLog("Failed to clear items: \(error.localizedDescription)")
            // Handle the error appropriately - could show user notification
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            // Store the indices being deleted
            let deletedIndices = offsets.sorted()
            
            // Delete the items
            offsets.map { filteredItems[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
                
                // Handle selection after deletion (following guide recommendations)
                if deletedIndices.contains(selectedIndex) {
                    // Selected item was deleted, select the new top item
                    selectedIndex = 0
                    if !filteredItems.isEmpty {
                        selectedItem = filteredItems[0]
                    } else {
                        selectedItem = nil
                    }
                } else if let minDeletedIndex = deletedIndices.first, minDeletedIndex < selectedIndex {
                    // Items before the selected item were deleted, adjust index
                    let deletedBeforeSelected = deletedIndices.filter { $0 < selectedIndex }.count
                    selectedIndex = max(0, selectedIndex - deletedBeforeSelected)
                    
                    // Ensure the selected item is still valid
                    if selectedIndex < filteredItems.count {
                        selectedItem = filteredItems[selectedIndex]
                    } else {
                        selectedIndex = 0
                        selectedItem = filteredItems.first
                    }
                }
            } catch {
                debugLog("Failed to delete items: \(error.localizedDescription)")
                // Handle the error appropriately - could show user notification
            }
        }
    }
    
    private func scrollToSelectedItem(proxy: ScrollViewProxy, index: Int) {
        // Guard against invalid index
        guard index >= 0 && index < filteredItems.count else { return }
        
        let selectedItem = filteredItems[index]
        
        // Ensure the item has a valid ID
        guard let itemId = selectedItem.id else { return }
        
        // Scroll to the selected item with smooth animation
        // Use .center anchor to keep the selected item in view
        withAnimation(.easeInOut(duration: 0.2)) {
            proxy.scrollTo(itemId, anchor: .center)
        }
    }
}
