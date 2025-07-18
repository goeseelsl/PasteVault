import SwiftUI
import AppKit

// MARK: - Debug Logging
#if DEBUG
private func debugLog(_ message: String) {
    print("📊 [OrganizationWindow] \(message)")
}
#else
private func debugLog(_ message: String) { }
#endif

/// Window controller for the clipboard organization window
class OrganizationWindowController: NSWindowController, NSWindowDelegate {
    convenience init() {
        // Create the window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Configure window
        window.title = "Clipboard Organization"
        window.center()
        window.setFrameAutosaveName("OrganizationWindow")
        window.minSize = NSSize(width: 1000, height: 700)
        window.isReleasedWhenClosed = false
        window.toolbarStyle = .unified
        window.level = .floating  // Set window level to ensure it appears above other windows
        
        // Set content view with the proper managed object context
        let viewContext = PersistenceController.shared.container.viewContext
        let organizationView = OrganizationWindowView()
            .environment(\.managedObjectContext, viewContext)
        window.contentView = NSHostingView(rootView: organizationView)
        
        // Initialize with our window
        self.init(window: window)
        window.delegate = self
    }
    
    // Window delegate methods
    func windowWillClose(_ notification: Notification) {
        // Any cleanup needed when window is closed
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        // Ensure the app is in front when this window becomes key
        if let window = notification.object as? NSWindow {
            NSApp.activate(ignoringOtherApps: true)
            window.orderFrontRegardless()
        }
    }
    
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        
        if let window = self.window {
            // Ensure the window is at the floating level and in front
            window.level = .floating
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }
}

/// SwiftUI View to show organization window content
struct OrganizationWindowView: View {
    @Environment(\.managedObjectContext) private var viewContext
    // Use StateObject to create a single instance that persists across view updates
    @StateObject private var folderManager: FolderManager
    @StateObject private var searchManager = SearchManager()
    @State private var selectedView: ViewMode = .list
    @State private var advancedSearchExpanded = false
    @State private var selectedItems: Set<UUID> = []
    @State private var selectedContentTypeFilter: ContentTypeFilter = .all
    @State private var selectedQuickFilter: QuickFilter = .all
    
    enum ViewMode {
        case list, grid, card
    }
    
    enum ContentTypeFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case text = "Text"
        case urls = "URLs"
        case images = "Images"
        case files = "Files"
        case numbers = "Numbers"
        case emails = "Emails"
        case colors = "Colors"
        
        var id: String { self.rawValue }
        
        var icon: String {
            switch self {
            case .all: return "tray.full"
            case .text: return "doc.text"
            case .urls: return "link"
            case .images: return "photo"
            case .files: return "folder"
            case .numbers: return "number"
            case .emails: return "envelope"
            case .colors: return "paintpalette"
            }
        }
        
        var emoji: String {
            switch self {
            case .all: return "📋"
            case .text: return "📄"
            case .urls: return "🔗"
            case .images: return "🖼️"
            case .files: return "📁"
            case .numbers: return "🔢"
            case .emails: return "📧"
            case .colors: return "🎨"
            }
        }
    }
    
    enum QuickFilter: String, CaseIterable, Identifiable {
        case all = "All Items"
        case favorites = "Favorites"
        case today = "Today"
        case thisWeek = "This Week"
        case secure = "Secure"
        
        var id: String { self.rawValue }
        
        var icon: String {
            switch self {
            case .all: return "tray.full"
            case .favorites: return "star.fill"
            case .today: return "calendar.day.timeline.left"
            case .thisWeek: return "calendar.badge.clock"
            case .secure: return "lock.fill"
            }
        }
        
        var emoji: String {
            switch self {
            case .all: return "📋"
            case .favorites: return "⭐"
            case .today: return "📅"
            case .thisWeek: return "📆"
            case .secure: return "🔒"
            }
        }
    }
    
    @FetchRequest private var items: FetchedResults<ClipboardItem>
    
    // Initialize with the correct managed object context
    init() {
        // Configure folder manager
        _folderManager = StateObject(wrappedValue: FolderManager(viewContext: PersistenceController.shared.container.viewContext))
        
        // Configure the fetch request for clipboard items with proper sort descriptors
        let fetchRequest = NSFetchRequest<ClipboardItem>(entityName: "ClipboardItem")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItem.createdAt, ascending: false)]
        
        // Set the predefined fetch request
        _items = FetchRequest<ClipboardItem>(fetchRequest: fetchRequest)
        
        debugLog("OrganizationWindowView initialized with fetch request")
    }
    
    var filteredItems: [ClipboardItem] {
        var result = Array(items)
        
        debugLog("Total items in database: \(result.count)")
        
        // Apply content type filter
        if selectedContentTypeFilter != .all {
            result = result.filter { item in
                switch selectedContentTypeFilter {
                case .all:
                    return true
                case .text:
                    return item.content != nil && item.imageData == nil
                case .urls:
                    return ContentHelper.isURL(item.content ?? "")
                case .images:
                    return item.imageData != nil
                case .files:
                    return item.category == "file"
                case .numbers:
                    return ContentHelper.isNumber(item.content ?? "")
                case .emails:
                    return ContentHelper.isEmail(item.content ?? "")
                case .colors:
                    return ContentHelper.isColorCode(item.content ?? "")
                }
            }
            debugLog("After content type filter (\(selectedContentTypeFilter.rawValue)): \(result.count)")
        }
        
        // Apply quick filter
        switch selectedQuickFilter {
        case .all:
            break // No filtering needed
        case .favorites:
            result = result.filter { $0.isFavorite }
            debugLog("After favorites filter: \(result.count)")
        case .today:
            result = result.filter { item in
                guard let date = item.createdAt else { return false }
                return Calendar.current.isDateInToday(date)
            }
            debugLog("After today filter: \(result.count)")
        case .thisWeek:
            result = result.filter { item in
                guard let date = item.createdAt else { return false }
                let calendar = Calendar.current
                let components = calendar.dateComponents([.weekOfYear], from: date, to: Date())
                return components.weekOfYear ?? 2 <= 1
            }
            debugLog("After this week filter: \(result.count)")
        case .secure:
            result = result.filter { $0.isFavorite }
            debugLog("After secure filter: \(result.count)")
        }
        
        // Apply folder filter
        if let selectedFolder = folderManager.selectedFolder {
            result = result.filter { $0.folder == selectedFolder }
            debugLog("After folder filter: \(result.count)")
        }
        
        // Apply search
        if !searchManager.searchText.isEmpty {
            result = searchManager.fuzzySearch(items: result)
            debugLog("After search filter: \(result.count)")
        }
        
        debugLog("Final filtered count: \(result.count)")
        return result
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left Panel: Filters & Navigation (300px width)
            VStack(alignment: .leading, spacing: 0) {
                // Content Type Filters
                FiltersGroupView(title: "Content Types") {
                    ForEach(ContentTypeFilter.allCases) { filter in
                        FilterButtonView(
                            title: filter.rawValue,
                            icon: filter.icon,
                            emoji: filter.emoji,
                            isSelected: selectedContentTypeFilter == filter,
                            action: { selectedContentTypeFilter = filter }
                        )
                    }
                }
                
                Divider().padding(.vertical, 8)
                
                // Quick Filters
                FiltersGroupView(title: "Quick Filters") {
                    ForEach(QuickFilter.allCases) { filter in
                        FilterButtonView(
                            title: filter.rawValue,
                            icon: filter.icon,
                            emoji: filter.emoji,
                            isSelected: selectedQuickFilter == filter,
                            action: { selectedQuickFilter = filter }
                        )
                    }
                }
                
                Divider().padding(.vertical, 8)
                
                // Folder Management
                FolderManagementView(folderManager: folderManager)
                
                Spacer()
            }
            .frame(width: 300)
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Right Panel: Content & Search
            VStack(spacing: 0) {
                // Top Section: Advanced Search Bar
                OrganizationAdvancedSearchView(searchManager: searchManager, isExpanded: $advancedSearchExpanded)
                
                Divider().padding(.vertical, 4)
                
                // View Mode Toolbar
                HStack {
                    Text("\(filteredItems.count) items")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: { selectedView = .list }) {
                        Image(systemName: "list.bullet")
                            .foregroundColor(selectedView == .list ? .accentColor : .secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: { selectedView = .grid }) {
                        Image(systemName: "square.grid.2x2")
                            .foregroundColor(selectedView == .grid ? .accentColor : .secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: { selectedView = .card }) {
                        Image(systemName: "rectangle.grid.1x2")
                            .foregroundColor(selectedView == .card ? .accentColor : .secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Main Content Area
                Group {
                    if filteredItems.isEmpty {
                        emptyStateView
                    } else {
                        contentView
                    }
                }
                .onAppear {
                    debugLog("Main content area appeared with \(filteredItems.count) items")
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    // Export selected items
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    // Delete selected items
                }) {
                    Image(systemName: "trash")
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    // Create new folder
                    folderManager.showFolderCreation = true
                }) {
                    Image(systemName: "folder.badge.plus")
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Picker("", selection: $selectedView) {
                    Image(systemName: "list.bullet").tag(ViewMode.list)
                    Image(systemName: "square.grid.2x2").tag(ViewMode.grid)
                    Image(systemName: "rectangle.grid.1x2").tag(ViewMode.card)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 120)
            }
        }
        .sheet(isPresented: $folderManager.showFolderCreation) {
            FolderCreationView(folderManager: folderManager)
        }
    }
    
    var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No items match your filters")
                .font(.title2)
                .foregroundColor(.primary)
            
            Text("Database contains \(items.count) items, but filtered list is empty")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button("Clear Filters") {
                selectedContentTypeFilter = .all
                selectedQuickFilter = .all
                folderManager.selectedFolder = nil
                searchManager.searchText = ""
            }
            .buttonStyle(BorderedButtonStyle())
            .controlSize(.large)
            .padding(.top, 8)
            
            Button("Debug - Fetch Raw Items") {
                // Direct Core Data fetch to debug
                let fetchRequest: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
                fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItem.createdAt, ascending: false)]
                do {
                    let fetchedItems = try viewContext.fetch(fetchRequest)
                    debugLog("Direct Core Data fetch returned \(fetchedItems.count) items")
                    for (index, item) in fetchedItems.prefix(5).enumerated() {
                        debugLog("Item \(index): id=\(String(describing: item.id)), content=\(String(describing: item.content?.prefix(30)))")
                    }
                } catch {
                    debugLog("Failed to fetch items: \(error.localizedDescription)")
                }
            }
            .buttonStyle(BorderedButtonStyle())
            .controlSize(.large)
            .padding(.top, 8)
            
            // Simple direct list to test item display
            Text("Simple Debug List")
                .font(.headline)
                .padding(.top, 20)
            
            ScrollView {
                LazyVStack(alignment: .leading) {
                    ForEach(Array(items.prefix(10)), id: \.id) { item in
                        Text(item.content ?? "No content")
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .padding(4)
                    }
                }
                .frame(height: 200)
                .border(Color.gray)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    var contentView: some View {
        Group {
            switch selectedView {
            case .list:
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // Invisible anchor at the top for reliable scrolling
                            Color.clear.frame(height: 0).id("top")
                            
                            ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                                OrganizationListItemView(
                                    item: item,
                                    isSelected: selectedItems.contains(item.id ?? UUID()),
                                    onSelect: { toggleSelection(item: item) }
                                )
                                .contextMenu {
                                    itemContextMenu(for: item)
                                }
                                .id(item.id)
                            }
                        }
                        .padding(.vertical, 0)
                        .onAppear {
                            scrollToTopAndHighlightFirst(scrollProxy: scrollProxy)
                        }
                        .onChange(of: filteredItems) { _ in
                            scrollToTopAndHighlightFirst(scrollProxy: scrollProxy)
                        }
                    }
                }
            case .grid:
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 12)], spacing: 12) {
                            // Invisible anchor at the top for reliable scrolling
                            Color.clear.frame(height: 0).id("top")
                            
                            ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                                OrganizationGridItemView(
                                    item: item,
                                    isSelected: selectedItems.contains(item.id ?? UUID()),
                                    onSelect: { toggleSelection(item: item) }
                                )
                                .contextMenu {
                                    itemContextMenu(for: item)
                                }
                                .id(item.id)
                            }
                        }
                        .padding()
                        .onAppear {
                            scrollToTopAndHighlightFirst(scrollProxy: scrollProxy)
                        }
                        .onChange(of: filteredItems) { _ in
                            scrollToTopAndHighlightFirst(scrollProxy: scrollProxy)
                        }
                    }
                }
            case .card:
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // Invisible anchor at the top for reliable scrolling
                            Color.clear.frame(height: 0).id("top")
                            
                            ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                                OrganizationCardItemView(
                                    item: item,
                                    isSelected: selectedItems.contains(item.id ?? UUID()),
                                    onSelect: { toggleSelection(item: item) }
                                )
                                .contextMenu {
                                    itemContextMenu(for: item)
                                }
                                .id(item.id)
                            }
                        }
                        .padding()
                        .onAppear {
                            scrollToTopAndHighlightFirst(scrollProxy: scrollProxy)
                        }
                        .onChange(of: filteredItems) { _ in
                            scrollToTopAndHighlightFirst(scrollProxy: scrollProxy)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    func itemContextMenu(for item: ClipboardItem) -> some View {
        Button(action: {
            clipboardManagerInstance.copyToPasteboard(item: item)
        }) {
            Label("Copy", systemImage: "doc.on.doc")
        }
        
        Button(action: {
            clipboardManagerInstance.performPasteOperation(item: item) { success in
                if success {
                    print("✅ Item pasted successfully")
                } else {
                    print("❌ Failed to paste item")
                }
            }
        }) {
            Label("Paste", systemImage: "doc.on.clipboard")
        }
        
        Menu("Move to Folder") {
            Button("No Folder") {
                folderManager.moveItem(item, to: nil)
            }
            
            Divider()
            
            ForEach(Array(folderManager.allFolders), id: \.self) { folder in
                Button(folder.name ?? "Untitled") {
                    folderManager.moveItem(item, to: folder)
                }
            }
        }
        
        Button(action: {
            item.isFavorite.toggle()
            try? viewContext.save()
        }) {
            Label(item.isFavorite ? "Remove Favorite" : "Add to Favorites", systemImage: item.isFavorite ? "star.slash" : "star")
        }
        
        Button(action: {
            // Edit content
        }) {
            Label("Edit", systemImage: "pencil")
        }
        
        Divider()
        
        Button(action: {
            viewContext.delete(item)
            try? viewContext.save()
        }) {
            Label("Delete", systemImage: "trash")
        }
    }
    
    private func scrollToTopAndHighlightFirst(scrollProxy: ScrollViewProxy) {
        // Clear current selection and highlight first item
        selectedItems.removeAll()
        
        // Select first item if available
        if let firstItem = filteredItems.first, let firstItemId = firstItem.id {
            selectedItems.insert(firstItemId)
        }
        
        // Scroll to top with smooth animation using first item's ID
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.3)) {
                if let firstItem = filteredItems.first, let firstItemId = firstItem.id {
                    scrollProxy.scrollTo(firstItemId, anchor: .top)
                } else {
                    // If no items, scroll to top using the anchor
                    scrollProxy.scrollTo("top", anchor: .top)
                }
            }
        }
    }
    
    private func toggleSelection(item: ClipboardItem) {
        if let id = item.id {
            if selectedItems.contains(id) {
                selectedItems.remove(id)
            } else {
                selectedItems.insert(id)
            }
        }
    }
}

// Helper Views for Organization Window

/// Filter Group View
struct FiltersGroupView<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            content
        }
    }
}

/// Filter Button View
struct FilterButtonView: View {
    let title: String
    let icon: String
    let emoji: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            Text(emoji)
                .font(.system(size: 16))
                .frame(width: 24, alignment: .center)
            
            Text(title)
                .font(.system(size: 13))
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
    }
}

/// Folder Management View
struct FolderManagementView: View {
    @ObservedObject var folderManager: FolderManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("My Folders")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    folderManager.showFolderCreation = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 4)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(.blue)
                            .frame(width: 24, alignment: .center)
                        
                        Text("All Folders")
                            .font(.system(size: 13))
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(folderManager.selectedFolder == nil ? Color.accentColor.opacity(0.15) : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(folderManager.selectedFolder == nil ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        folderManager.selectedFolder = nil
                    }
                    
                    ForEach(Array(folderManager.allFolders), id: \.self) { folder in
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24, alignment: .center)
                            
                            Text(folder.name ?? "Untitled")
                                .font(.system(size: 13))
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text("\(folder.items?.count ?? 0)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.secondary.opacity(0.1))
                                )
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(folderManager.selectedFolder == folder ? Color.accentColor.opacity(0.15) : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(folderManager.selectedFolder == folder ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            folderManager.selectedFolder = folder
                        }
                        .contextMenu {
                            Button("Rename") {
                                folderManager.editingFolder = folder
                            }
                            
                            Button("Delete", role: .destructive) {
                                folderManager.deleteFolder(folder)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
        }
    }
}

/// Advanced Search View for Organization Window
struct OrganizationAdvancedSearchView: View {
    @ObservedObject var searchManager: SearchManager
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search by content, app, date...", text: $searchManager.searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchManager.searchText.isEmpty {
                    Button(action: {
                        searchManager.searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Divider()
                    .frame(height: 16)
                
                Button(action: {
                    isExpanded.toggle()
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 1)
                    )
            )
            
            // Advanced search options
            if isExpanded {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Date Range")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: $searchManager.dateRange) {
                            ForEach(SearchManager.DateRange.allCases, id: \.self) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 150)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Content Type")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: $searchManager.selectedSearchType) {
                            ForEach(SearchManager.SearchType.allCases, id: \.self) { type in
                                HStack {
                                    Image(systemName: type.icon)
                                    Text(type.rawValue)
                                }
                                .tag(type)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 150)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.textBackgroundColor).opacity(0.5))
                )
            }
        }
        .padding(12)
    }
}

/// List Item View for Organization Window
struct OrganizationListItemView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox
            Button(action: onSelect) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Preview/icon
            Group {
                if let imageData = item.imageData, let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .cornerRadius(4)
                } else if let content = item.content, ContentHelper.isURL(content) {
                    Image(systemName: "link")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                        .frame(width: 40, height: 40)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                } else {
                    Image(systemName: "doc.text")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .frame(width: 40, height: 40)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                if let content = item.content {
                    Text(content.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                } else if item.imageData != nil {
                    Text("Image")
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                }
                
                HStack(spacing: 6) {
                    if let sourceApp = item.sourceApp {
                        Text(sourceApp)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    if let createdAt = item.createdAt {
                        Text("•")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Text(createdAt, style: .relative)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Folder badge
            if let folder = item.folder {
                Text(folder.name ?? "Untitled")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue.opacity(0.1))
                    )
                    .foregroundColor(.blue)
            }
            
            // Favorite icon
            if item.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 12))
            }
            
            // Actions menu
            Menu {
                Button(action: {
                    clipboardManagerInstance.copyToPasteboard(item: item)
                }) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                
                Button(action: {
                    clipboardManagerInstance.performPasteOperation(item: item) { success in
                        if success {
                            debugLog("Item pasted successfully")
                        } else {
                            debugLog("Failed to paste item")
                        }
                    }
                }) {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                
                Divider()
                
                Button(action: {
                    // Edit the item
                }) {
                    Label("Edit", systemImage: "pencil")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.secondary)
            }
            .menuStyle(BorderlessButtonMenuStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            clipboardManagerInstance.copyToPasteboard(item: item)
        }
    }
}

/// Grid Item View for Organization Window
struct OrganizationGridItemView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Preview area
            ZStack(alignment: .topTrailing) {
                Group {
                    if let imageData = item.imageData, let nsImage = NSImage(data: imageData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 160, height: 120)
                    } else if let content = item.content, ContentHelper.isURL(content) {
                        ZStack {
                            Rectangle().fill(Color.blue.opacity(0.1))
                            Image(systemName: "link")
                                .font(.system(size: 32))
                                .foregroundColor(.blue)
                        }
                        .frame(width: 160, height: 120)
                    } else if let content = item.content {
                        ZStack {
                            Rectangle().fill(Color.secondary.opacity(0.05))
                            Text(content)
                                .font(.system(size: 11))
                                .foregroundColor(.primary)
                                .padding(8)
                                .lineLimit(5)
                        }
                        .frame(width: 160, height: 120)
                    } else {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.1))
                            .frame(width: 160, height: 120)
                    }
                }
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                
                // Selection checkbox
                Button(action: onSelect) {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .foregroundColor(isSelected ? .accentColor : .white)
                        .padding(4)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(6)
            }
            
            // Metadata
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let sourceApp = item.sourceApp {
                        Text(sourceApp)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    if let createdAt = item.createdAt {
                        Text(createdAt, style: .relative)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if item.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 10))
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(width: 160)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.textBackgroundColor))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .onTapGesture(count: 2) {
            clipboardManagerInstance.copyToPasteboard(item: item)
        }
    }
}

/// Card Item View for Organization Window
struct OrganizationCardItemView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Selection checkbox
            Button(action: onSelect) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Preview/icon
            Group {
                if let imageData = item.imageData, let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .cornerRadius(8)
                } else if let content = item.content, ContentHelper.isURL(content) {
                    ZStack {
                        Rectangle().fill(Color.blue.opacity(0.1))
                        Image(systemName: "link")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                    }
                    .frame(width: 80, height: 80)
                    .cornerRadius(8)
                } else {
                    ZStack {
                        Rectangle().fill(Color.secondary.opacity(0.05))
                        Image(systemName: "doc.text")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 80, height: 80)
                    .cornerRadius(8)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                if let content = item.content {
                    Text(content.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .lineLimit(3)
                } else if item.imageData != nil {
                    Text("Image")
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                }
                
                HStack(spacing: 8) {
                    if let sourceApp = item.sourceApp {
                        Label(sourceApp, systemImage: "app")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    if let createdAt = item.createdAt {
                        Text(formatDate(createdAt))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    if let folder = item.folder {
                        Label(folder.name ?? "Untitled", systemImage: "folder")
                            .font(.system(size: 11))
                            .foregroundColor(.blue)
                    }
                    
                    if item.isFavorite {
                        Label("Favorite", systemImage: "star.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.yellow)
                    }
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 12) {
                Button(action: {
                    clipboardManagerInstance.copyToPasteboard(item: item)
                }) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    // Edit item
                }) {
                    Image(systemName: "pencil")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(NSColor.textBackgroundColor))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .onTapGesture(count: 2) {
            clipboardManagerInstance.copyToPasteboard(item: item)
        }
    }
}

// Extension for FolderManager to support Organization Window
extension FolderManager {
    var allFolders: [Folder] {
        let fetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Folder.name, ascending: true)]
        do {
            return try PersistenceController.shared.container.viewContext.fetch(fetchRequest)
        } catch {
            debugLog("Error fetching folders: \(error.localizedDescription)")
            return []
        }
    }
}

// Extend ContentHelper for organization window types
extension ContentHelper {
    static func isColorCode(_ content: String) -> Bool {
        // Check if the content is a valid color code (e.g., #RRGGBB)
        let colorRegex = try? NSRegularExpression(pattern: "^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$")
        if let matches = colorRegex?.matches(in: content, range: NSRange(content.startIndex..., in: content)), !matches.isEmpty {
            return true
        }
        return false
    }
}

/// Helper function to format date for display
func formatDate(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
}
