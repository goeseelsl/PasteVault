import SwiftUI
import CoreData

/// Enhanced folder and favorites management system
class FolderManager: ObservableObject {
    @Published var selectedFolder: Folder?
    @Published var showFolderCreation = false
    @Published var newFolderName = ""
    @Published var editingFolder: Folder?
    
    private let viewContext: NSManagedObjectContext
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
    }
    
    /// Create a new folder
    func createFolder(name: String, parent: Folder? = nil) {
        let newFolder = Folder(context: viewContext)
        newFolder.id = UUID()
        newFolder.name = name
        newFolder.createdAt = Date()
        // Note: parent and colorHex not available in current Core Data model
        // newFolder.parent = parent
        // newFolder.colorHex = generateRandomColor()
        
        saveContext()
    }
    
    /// Delete a folder and handle its items
    func deleteFolder(_ folder: Folder) {
        // Move items to root (no folder)
        if let items = folder.items?.allObjects as? [ClipboardItem] {
            for item in items {
                item.folder = nil // Move to root level
            }
        }
        
        // Note: Subfolder logic not available in current Core Data model
        // Move subfolders to parent would require the parent property
        
        viewContext.delete(folder)
        saveContext()
    }
    
    /// Static method to close sidebar globally
    static func closeSidebar() {
        // Use both notification and UserDefaults approach for maximum compatibility
        UserDefaults.standard.set(false, forKey: "showFolderSidebar")
        NotificationCenter.default.post(name: NSNotification.Name("CloseFolderSidebar"), object: nil)
    }
    
    /// Toggle favorite status of an item
    func toggleFavorite(_ item: ClipboardItem) {
        item.isFavorite.toggle()
        // Note: favoritedAt not available in current Core Data model
        // if item.isFavorite {
        //     item.favoritedAt = Date()
        // } else {
        //     item.favoritedAt = nil
        // }
        saveContext()
    }
    
    /// Move item to folder
    func moveItem(_ item: ClipboardItem, to folder: Folder?) {
        item.folder = folder
        saveContext()
    }
    
    /// Generate random color for folder
    private func generateRandomColor() -> String {
        let colors = ["#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7", "#DDA0DD", "#98D8C8", "#F7DC6F"]
        return colors.randomElement() ?? "#4ECDC4"
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
}

/// Enhanced folder sidebar view
struct FolderSidebarView: View {
    @ObservedObject var folderManager: FolderManager
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Folder.createdAt, ascending: true)]
    ) var allFolders: FetchedResults<Folder>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ClipboardItem.createdAt, ascending: false)],
        predicate: NSPredicate(format: "isFavorite == true")
    ) var favoriteItems: FetchedResults<ClipboardItem>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Folders")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    folderManager.showFolderCreation = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        // All Items
                        FolderRowView(
                            name: "All Items",
                            icon: "tray.full",
                            color: .blue,
                            itemCount: nil,
                            isSelected: folderManager.selectedFolder == nil,
                            onTap: { folderManager.selectedFolder = nil }
                        )
                        .padding(.bottom, 4)
                        .id("all-items") // Use a fixed ID for the first item
                        
                        // Favorites
                        FolderRowView(
                            name: "Favorites",
                            icon: "heart.fill",
                            color: .red,
                            itemCount: favoriteItems.count,
                            isSelected: false,
                            onTap: { /* Handle favorites view */ }
                        )
                        .padding(.bottom, 4)
                        
                        // Root folders
                        ForEach(allFolders, id: \.self) { folder in
                            FolderHierarchyView(
                                folder: folder,
                                selectedFolder: folderManager.selectedFolder,
                                onSelect: { folderManager.selectedFolder = folder },
                                onEdit: { folderManager.editingFolder = folder },
                                onDelete: { folderManager.deleteFolder(folder) }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .onAppear {
                        scrollToTopAndHighlightFirst(scrollProxy: scrollProxy)
                    }
                }
            }
        }
        .frame(width: 200)
        .background(Color(NSColor.controlBackgroundColor))
        .sheet(isPresented: $folderManager.showFolderCreation) {
            FolderCreationView(folderManager: folderManager)
        }
    }
    
    private func scrollToTopAndHighlightFirst(scrollProxy: ScrollViewProxy) {
        // Select "All Items" as default when sidebar appears
        folderManager.selectedFolder = nil
        
        // Scroll to top with smooth animation
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.3)) {
                scrollProxy.scrollTo("all-items", anchor: .top)
            }
        }
    }
}

/// Individual folder row view
struct FolderRowView: View {
    let name: String
    let icon: String
    let color: Color
    let itemCount: Int?
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color)
                .frame(width: 16)
            
            Text(name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Spacer()
            
            if let count = itemCount {
                Text("\(count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.1))
                    )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .onTapGesture(perform: onTap)
    }
}

/// Hierarchical folder view with subfolders
struct FolderHierarchyView: View {
    let folder: Folder
    let selectedFolder: Folder?
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Main folder row
            HStack(spacing: 4) {
                if hasSubfolders {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 12)
                } else {
                    Spacer().frame(width: 12)
                }
                
                Circle()
                    .fill(Color.blue) // Default color since colorHex not available
                    .frame(width: 12, height: 12)
                
                Text(folder.name ?? "Untitled")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                Text("\(folder.items?.count ?? 0)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.1))
                    )
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selectedFolder == folder ? Color.accentColor.opacity(0.2) : Color.clear)
                    .animation(.easeInOut(duration: 0.15), value: selectedFolder == folder)
            )
            .onTapGesture(perform: onSelect)
            .contextMenu {
                Button("Edit") { onEdit() }
                Button("Delete", role: .destructive) { onDelete() }
            }
            
            // Subfolders (if expanded) - not available in current Core Data model
            // if isExpanded, let subfolders = folder.subfolders?.allObjects as? [Folder] {
            //     ForEach(subfolders, id: \.self) { subfolder in
            //         FolderHierarchyView(
            //             folder: subfolder,
            //             selectedFolder: selectedFolder,
            //             onSelect: { /* Handle subfolder selection */ },
            //             onEdit: onEdit,
            //             onDelete: onDelete
            //         )
            //         .padding(.leading, 16)
            //     }
            // }
        }
    }
    
    private var hasSubfolders: Bool {
        // Note: subfolders not available in current Core Data model
        return false
    }
}

/// Folder creation dialog
struct FolderCreationView: View {
    @ObservedObject var folderManager: FolderManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Create New Folder")
                .font(.system(size: 16, weight: .semibold))
            
            TextField("Folder Name", text: $folderManager.newFolderName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                
                Button("Create") {
                    folderManager.createFolder(name: folderManager.newFolderName)
                    folderManager.newFolderName = ""
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(folderManager.newFolderName.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

/// Color extension for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
