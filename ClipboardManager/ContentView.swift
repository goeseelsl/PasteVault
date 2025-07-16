import SwiftUI
import CoreData
import Foundation
import AppKit
import Carbon

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject private var clipboardManager = ClipboardManager.shared
    @StateObject private var keyboardMonitor = KeyboardMonitor()
    @AppStorage("sidebarPosition") private var sidebarPosition = "right"

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ClipboardItem.createdAt, ascending: false)],
        animation: .default)
    private var items: FetchedResults<ClipboardItem>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Folder.createdAt, ascending: true)],
        animation: .default)
    private var folders: FetchedResults<Folder>

    @State private var searchText = ""
    @State private var selectedFolder: Folder?
    @State private var selectedItem: ClipboardItem?
    @State private var selectedIndex = 0
    @State private var refreshID = UUID()

    var body: some View {
        Group {
            if sidebarPosition == "left" || sidebarPosition == "right" {
                verticalLayout
            } else {
                horizontalLayout
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .edgesIgnoringSafeArea(.all)
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure the view expands to fill available space
    }
    
    private var verticalLayout: some View {
        VStack(spacing: 0) {
            // Header with search
            VStack(spacing: 8) {
                HeaderView {
                    if let appDelegate = NSApp.delegate as? AppDelegate {
                        appDelegate.openSettings(nil)
                    }
                }
                
                SearchView(searchText: $searchText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // List of clipboard items
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                            ClipboardNoteCard(
                                item: item,
                                isSelected: index == selectedIndex,
                                onTap: {
                                    handleItemSelection(item: item, index: index)
                                }
                            )
                            .id(item.id)
                            .contextMenu {
                                ContextMenuView(
                                    item: item,
                                    folders: Array(folders),
                                    onSave: saveContext,
                                    onCreateFolder: { createNewFolder(for: item) },
                                    onDelete: {
                                        viewContext.delete(item)
                                        saveContext()
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .onChange(of: selectedIndex) { newIndex in
                    scrollToSelectedItem(proxy: proxy, index: newIndex)
                }
            }
            
            // Footer
            if !filteredItems.isEmpty {
                FooterView(itemCount: filteredItems.count) {
                    clearAllItems()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Use maxWidth and maxHeight to fill available space
        .id(refreshID)
        .focusable()
        .onAppear {
            setupInitialState()
        }
        .onDisappear {
            keyboardMonitor.stopMonitoring()
        }
        .onReceive(keyboardMonitor.$keyPressed) { keyPressed in
            handleKeyPress(keyPressed)
        }
        .onReceive(clipboardManager.$updateTrigger) { _ in
            refreshView()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ClipboardUpdated"))) { _ in
            DispatchQueue.main.async {
                refreshView()
            }
        }
        .onChange(of: filteredItems) { newItems in
            resetSelection(for: newItems)
        }
    }
    
    private var horizontalLayout: some View {
        HStack(spacing: 0) {
            // Left side with header and search
            sidePanel
            
            Divider()
            
            // Right side with clipboard items
            clipboardItemsList
        }
    }
    
    private var sidePanel: some View {
        VStack(spacing: 8) {
            HeaderView {
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.openSettings(nil)
                }
            }
            
            SearchView(searchText: $searchText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .frame(width: 250)
    }
    
    private var clipboardItemsList: some View {
        ScrollViewReader { proxy in
            clipboardScrollView(proxy: proxy)
        }
    }
    
    private func clipboardScrollView(proxy: ScrollViewProxy) -> some View {
        ScrollView {
            clipboardItemsStack
                .padding(8)
                .onAppear {
                    if let firstItem = filteredItems.first {
                        proxy.scrollTo(firstItem.id, anchor: .top)
                    }
                }
        }
    }
    
    private var clipboardItemsStack: some View {
        LazyVStack(spacing: 4) {
            ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                clipboardItemView(item: item, index: index)
            }
        }
    }
    
    private func clipboardItemView(item: ClipboardItem, index: Int) -> some View {
        ClipboardNoteCard(
            item: item, 
            isSelected: selectedItem?.id == item.id,
            onTap: {
                self.selectedItem = item
                self.selectedIndex = index
            }
        )
        .background(selectedItem?.id == item.id ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
        .id(item.id)
        .onAppear {
            // No-op for now - will be implemented in the future
        }
    }

    // MARK: - Computed Properties
    
    private var filteredItems: [ClipboardItem] {
        let predicate = ContentPredicateBuilder.buildPredicate(
            searchText: searchText,
            selectedFolder: selectedFolder
        )
        
        let fetchRequest = NSFetchRequest<ClipboardItem>(entityName: "ClipboardItem")
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItem.createdAt, ascending: false)]
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            return ContentPredicateBuilder.postFilterResults(results, searchText: searchText)
        } catch {
            print("Error fetching filtered items: \(error)")
            return []
        }
    }
    
    // MARK: - Event Handlers
    
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
        
        // Close edge window first
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.closeEdgeWindow()
        }
        
        // Paste the item directly after a brief delay using optimized method
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            print("🚀 Pasting selected item directly")
            clipboardManager.performPasteOperation(item: item) { success in
                if success {
                    print("✅ Paste operation completed successfully")
                } else {
                    print("❌ Paste operation failed")
                }
            }
        }
    }
    
    private func handleKeyPress(_ keyPressed: (String, Bool)?) {
        guard let (key, isPressed) = keyPressed, isPressed else { return }
        
        print("🎹 Key pressed: \(key)")
        
        switch key {
        case "down":
            if !filteredItems.isEmpty {
                selectedIndex = min(selectedIndex + 1, filteredItems.count - 1)
            }
        case "up":
            if !filteredItems.isEmpty {
                selectedIndex = max(selectedIndex - 1, 0)
            }
        case "return":
            print("🎹 Return key detected, calling handleReturnKeyPress")
            handleReturnKeyPress()
        case "escape":
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.closeEdgeWindow()
            }
        default:
            break
        }
    }
    
    private func handleReturnKeyPress() {
        print("🎹 Enter key pressed - starting paste operation")
        
        guard !filteredItems.isEmpty && selectedIndex < filteredItems.count else { return }
        
        let item = filteredItems[selectedIndex]
        selectedItem = item
        print("Selected item: \(item.content?.prefix(50) ?? "Image/No content")")
        
        // Close edge window first
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.closeEdgeWindow()
            print("Edge window closed")
        }
        
        // Copy the item to pasteboard - user can then paste manually with Cmd+V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            print("� Copying item to pasteboard")
            clipboardManager.performPasteOperation(item: item) { success in
                if success {
                    print("✅ Item copied to pasteboard - ready for manual paste with Cmd+V")
                } else {
                    print("❌ Failed to copy item to pasteboard")
                }
            }
        }
    }
    
    private func scrollToSelectedItem(proxy: ScrollViewProxy, index: Int) {
        if !filteredItems.isEmpty && index < filteredItems.count {
            let selectedItem = filteredItems[index]
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(selectedItem.id, anchor: UnitPoint.center)
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
    
    // MARK: - Core Data Operations
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("Error saving context: \(nsError), \(nsError.userInfo)")
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
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "ClipboardItem")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try viewContext.execute(deleteRequest)
            try viewContext.save()
        } catch {
            print("Error clearing all items: \(error)")
        }
    }
    
    // MARK: - Paste Operations
    
    private func performAutoPaste() {
        print("🚀 Starting fallback paste operation")
        // Use system paste instead of PasteHelper for simple paste
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true) // V key
        event?.flags = .maskCommand
        event?.post(tap: .cghidEventTap)
        
        let eventUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false)
        eventUp?.flags = .maskCommand
        eventUp?.post(tap: .cghidEventTap)
    }
}

// MARK: - Context Menu Component

struct ContextMenuView: View {
    let item: ClipboardItem
    let folders: [Folder]
    let onSave: () -> Void
    let onCreateFolder: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Group {
            Button("Copy") {
                ClipboardManager.shared.copyToPasteboard(item: item)
            }
            
            Button("Paste") {
                ClipboardManager.shared.performPasteOperation(item: item) { success in
                    if !success {
                        print("❌ Context menu paste operation failed")
                    }
                }
            }
            
            Button("Pin/Unpin") {
                item.isPinned.toggle()
                onSave()
            }
            
            Menu("Move to Folder") {
                Button("No Folder") {
                    item.folder = nil
                    onSave()
                }
                ForEach(folders, id: \.self) { folder in
                    Button(folder.name ?? "Unnamed") {
                        item.folder = folder
                        onSave()
                    }
                }
                Button("New Folder...") {
                    onCreateFolder()
                }
            }
            
            Divider()
            
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}
