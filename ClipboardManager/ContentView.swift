import SwiftUI
import CoreData
import Foundation
import AppKit
import Carbon

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject private var clipboardManager = ClipboardManager.shared
    @StateObject private var keyboardMonitor = KeyboardMonitor()
    @StateObject private var searchManager = SearchManager()
    @StateObject private var folderManager: FolderManager
    @StateObject private var bulkActionsManager: BulkActionsManager
    @StateObject private var customActionsManager = CustomActionsManager()
    @StateObject private var contentFilterManager = ContentFilterManager()
    @StateObject private var globalShortcutsManager = GlobalShortcutsManager()
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
                // Collapsible sidebar
                if showFolderSidebar {
                    FolderSidebarView(folderManager: folderManager)
                        .frame(width: max(200, geometry.size.width * 0.25))
                        .transition(.move(edge: .leading))
                }
                
                // Main content area
                VStack(spacing: 0) {
                    // Header
                    HeaderView(
                        onSettingsPressed: {
                            if let appDelegate = NSApp.delegate as? AppDelegate {
                                appDelegate.openSettings(nil)
                            }
                        },
                        onToggleFolders: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showFolderSidebar.toggle()
                            }
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    // Search
                    SearchView(searchText: $searchManager.searchText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    
                    // Content
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                                EnhancedClipboardCard(
                                    item: item,
                                    isSelected: bulkActionsManager.isSelectionMode ? bulkActionsManager.selectedItems.contains(item) : (index == selectedIndex),
                                    selectionIndex: index,
                                    onToggleFavorite: {
                                        item.isFavorite.toggle()
                                        try? viewContext.save()
                                    },
                                    onCopyToClipboard: {
                                        // Close sidebar when copying to clipboard - FIRST
                                        let wasSidebarOpen = showFolderSidebar
                                        if wasSidebarOpen {
                                            print("🔄 Closing sidebar for copy button operation")
                                            showFolderSidebar = false
                                        } else {
                                            print("📋 Sidebar was already closed for copy button")
                                        }
                                        
                                        ClipboardManager.shared.copyToPasteboard(item: item)
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
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    
                    // Footer
                    if !filteredItems.isEmpty {
                        FooterView(itemCount: filteredItems.count) {
                            clearAllItems()
                        }
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
        }
        .onReceive(keyboardMonitor.$keyPressed) { keyPressed in
            if let (key, isPressed) = keyPressed, isPressed {
                handleKeyPress(key)
            }
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
            !contentFilterManager.shouldIgnoreContent(item.content, from: item.sourceApp)
        }
        
        // Apply search manager filters
        if !searchManager.searchText.isEmpty {
            filtered = searchManager.fuzzySearch(items: filtered)
        }
        
        // Apply type filter
        filtered = searchManager.filterByType(items: filtered)
        
        // Apply date filter
        filtered = searchManager.filterByDate(items: filtered)
        
        // Apply folder filter
        if let selectedFolder = selectedFolder {
            filtered = filtered.filter { $0.folder == selectedFolder }
        }
        
        // Apply source app filter
        if let selectedSourceApp = selectedSourceApp {
            filtered = filtered.filter { $0.sourceApp == selectedSourceApp }
        }
        
        return filtered
    }
    
    private func setupInitialState() {
        selectedIndex = 0
        if let firstItem = filteredItems.first {
            selectedItem = firstItem
        }
        keyboardMonitor.startMonitoring()
    }
    
    private func handleItemSelection(item: ClipboardItem, index: Int) {
        selectedItem = item
        selectedIndex = index
        
        // Close sidebar when pasting - FIRST, before closing window
        let wasSidebarOpen = showFolderSidebar
        if wasSidebarOpen {
            print("🔄 Closing sidebar for handleItemSelection paste operation")
            showFolderSidebar = false
        } else {
            print("📋 Sidebar was already closed for handleItemSelection")
        }
        
        // Close edge window after sidebar state change
        NSApp.windows.first { $0.title == "ClipboardManager" }?.close()
        
        // Copy to clipboard and paste
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            clipboardManager.performPasteOperation(item: item) { success in
                if success {
                    print("✅ Paste operation completed successfully")
                } else {
                    print("❌ Paste operation failed")
                }
            }
        }
    }
    
    private func handleKeyPress(_ keyPressed: String) {
        switch keyPressed {
        case "down":
            if !filteredItems.isEmpty {
                selectedIndex = min(selectedIndex + 1, filteredItems.count - 1)
            }
        case "up":
            if !filteredItems.isEmpty {
                selectedIndex = max(selectedIndex - 1, 0)
            }
        case "return":
            handleEnterKey()
        default:
            break
        }
    }
    
    private func handleEnterKey() {
        guard !filteredItems.isEmpty && selectedIndex < filteredItems.count else { return }
        
        let item = filteredItems[selectedIndex]
        selectedItem = item
        
        // Close sidebar when pasting - FIRST, before closing window
        let wasSidebarOpen = showFolderSidebar
        if wasSidebarOpen {
            print("🔄 Closing sidebar for handleEnterKey paste operation")
            showFolderSidebar = false
        } else {
            print("📋 Sidebar was already closed for handleEnterKey")
        }
        
        // Close edge window after sidebar state change
        NSApp.windows.first { $0.title == "ClipboardManager" }?.close()
        
        // Copy to clipboard and paste
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            clipboardManager.performPasteOperation(item: item) { success in
                if success {
                    print("✅ Item pasted successfully")
                } else {
                    print("❌ Paste operation failed")
                }
            }
        }
    }
    
    private func refreshView() {
        selectedIndex = 0
        if selectedItem == nil, let firstItem = filteredItems.first {
            selectedItem = firstItem
        }
        refreshID = UUID()
    }
    
    private func resetSelection(for newItems: [ClipboardItem]) {
        selectedIndex = 0
        if let firstItem = newItems.first {
            selectedItem = firstItem
        }
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
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
            print("Error clearing items: \(error)")
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredItems[$0] }.forEach(viewContext.delete)
            do {
                try viewContext.save()
            } catch {
                print("Error deleting items: \(error)")
            }
        }
    }
    
    private func scrollToSelectedItem(proxy: ScrollViewProxy, index: Int) {
        if index < filteredItems.count {
            proxy.scrollTo(filteredItems[index].id, anchor: .center)
        }
    }
    
    private func performAutoPaste() {
        // Create and dispatch key events for Command+V
        let eventDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true)
        let eventUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false)
        
        eventDown?.flags = .maskCommand
        eventUp?.flags = .maskCommand
        
        eventDown?.post(tap: .cghidEventTap)
        eventUp?.post(tap: .cghidEventTap)
    }
}
