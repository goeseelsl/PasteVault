import SwiftUI
import CoreData
import AppKit

/// Bulk actions and direct paste functionality
class BulkActionsManager: ObservableObject {
    @Published var selectedItems: Set<ClipboardItem> = []
    @Published var isSelectionMode = false
    @Published var showBulkActions = false
    
    private let viewContext: NSManagedObjectContext
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
    }
    
    /// Toggle selection mode
    func toggleSelectionMode() {
        isSelectionMode.toggle()
        if !isSelectionMode {
            selectedItems.removeAll()
        }
    }
    
    /// Toggle item selection
    func toggleSelection(for item: ClipboardItem) {
        if selectedItems.contains(item) {
            selectedItems.remove(item)
        } else {
            selectedItems.insert(item)
        }
    }
    
    /// Select all items
    func selectAll(_ items: [ClipboardItem]) {
        selectedItems = Set(items)
    }
    
    /// Clear selection
    func clearSelection() {
        selectedItems.removeAll()
    }
    
    /// Bulk paste all selected items
    func bulkPaste(separator: String = "\n") {
        let sortedItems = selectedItems.sorted { $0.createdAt ?? Date() > $1.createdAt ?? Date() }
        let combinedText = sortedItems.compactMap { $0.content }.joined(separator: separator)
        
        // Copy to pasteboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(combinedText, forType: .string)
        
        // Perform paste
        performAutoPaste()
    }
    
    /// Convert selected items to plain text
    func convertToPlainText() {
        for item in selectedItems {
            if let content = item.content {
                // Strip formatting by removing HTML tags and extra whitespace
                let plainText = content
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                item.content = plainText
            }
        }
        
        saveContext()
    }
    
    /// Delete selected items
    func deleteSelectedItems() {
        for item in selectedItems {
            viewContext.delete(item)
        }
        selectedItems.removeAll()
        saveContext()
    }
    
    /// Export selected items to file
    func exportToFile() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "clipboard_export.txt"
        panel.allowedContentTypes = [.plainText, .json]
        
        if panel.runModal() == .OK, let url = panel.url {
            exportItems(to: url)
        }
    }
    
    /// Pin/Unpin selected items
    func togglePinSelectedItems() {
        let shouldPin = !selectedItems.allSatisfy { $0.isPinned }
        
        for item in selectedItems {
            item.isPinned = shouldPin
        }
        
        saveContext()
    }
    
    /// Add selected items to folder
    func addToFolder(_ folder: Folder) {
        for item in selectedItems {
            item.folder = folder
        }
        saveContext()
    }
    
    private func exportItems(to url: URL) {
        let sortedItems = selectedItems.sorted { $0.createdAt ?? Date() > $1.createdAt ?? Date() }
        
        if url.pathExtension == "json" {
            exportAsJSON(items: sortedItems, to: url)
        } else {
            exportAsText(items: sortedItems, to: url)
        }
    }
    
    private func exportAsText(items: [ClipboardItem], to url: URL) {
        let content = items.compactMap { item -> String? in
            let timestamp = item.createdAt?.formatted() ?? "Unknown"
            let source = item.sourceApp ?? "Unknown"
            let text = item.content ?? "No content"
            
            return """
            =====================================
            Date: \(timestamp)
            Source: \(source)
            Content:
            \(text)
            
            """
        }.joined()
        
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            print("Error exporting to text: \(error)")
        }
    }
    
    private func exportAsJSON(items: [ClipboardItem], to url: URL) {
        let jsonItems = items.map { item in
            [
                "id": item.id?.uuidString ?? UUID().uuidString,
                "content": item.content ?? "",
                "sourceApp": item.sourceApp ?? "Unknown",
                "createdAt": item.createdAt?.timeIntervalSince1970 ?? 0,
                "isPinned": item.isPinned,
                "isFavorite": item.isFavorite,
                "category": item.category ?? ""
            ]
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jsonItems, options: .prettyPrinted)
            try jsonData.write(to: url)
        } catch {
            print("Error exporting to JSON: \(error)")
        }
    }
    
    private func performAutoPaste() {
        // Use system paste
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true) // V key
        event?.flags = .maskCommand
        event?.post(tap: .cghidEventTap)
        
        let eventUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false)
        eventUp?.flags = .maskCommand
        eventUp?.post(tap: .cghidEventTap)
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
}

/// Bulk actions toolbar
struct BulkActionsToolbar: View {
    @ObservedObject var bulkManager: BulkActionsManager
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Folder.createdAt, ascending: true)]
    ) var folders: FetchedResults<Folder>
    
    @State private var showSeparatorDialog = false
    @State private var pasteSeparator = "\n"
    
    var body: some View {
        if bulkManager.isSelectionMode {
            HStack(spacing: 12) {
                // Selection count
                Text("\(bulkManager.selectedItems.count) selected")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Actions
                HStack(spacing: 8) {
                    // Select All
                    Button("Select All") {
                        // This would need to be passed the current items
                        // bulkManager.selectAll(items)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                    // Clear Selection
                    Button("Clear") {
                        bulkManager.clearSelection()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                    // Bulk Paste
                    Button("Paste All") {
                        showSeparatorDialog = true
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(bulkManager.selectedItems.isEmpty)
                    
                    // More actions menu
                    Menu {
                        Button("Convert to Plain Text") {
                            bulkManager.convertToPlainText()
                        }
                        
                        Button("Toggle Pin") {
                            bulkManager.togglePinSelectedItems()
                        }
                        
                        Menu("Move to Folder") {
                            ForEach(folders, id: \.self) { folder in
                                Button(folder.name ?? "Untitled") {
                                    bulkManager.addToFolder(folder)
                                }
                            }
                        }
                        
                        Divider()
                        
                        Button("Export to File") {
                            bulkManager.exportToFile()
                        }
                        
                        Button("Delete All", role: .destructive) {
                            bulkManager.deleteSelectedItems()
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(bulkManager.selectedItems.isEmpty)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(Color.accentColor.opacity(0.1))
                    .overlay(
                        Rectangle()
                            .fill(Color.accentColor.opacity(0.3))
                            .frame(height: 1),
                        alignment: .bottom
                    )
            )
            .sheet(isPresented: $showSeparatorDialog) {
                SeparatorSelectionDialog(
                    separator: $pasteSeparator,
                    onPaste: {
                        bulkManager.bulkPaste(separator: pasteSeparator)
                    }
                )
            }
        }
    }
}

/// Separator selection dialog for bulk paste
struct SeparatorSelectionDialog: View {
    @Binding var separator: String
    @Environment(\.presentationMode) var presentationMode
    let onPaste: () -> Void
    
    let separatorOptions = [
        ("New Line", "\n"),
        ("Space", " "),
        ("Comma", ", "),
        ("Tab", "\t"),
        ("Semicolon", "; "),
        ("Custom", "custom")
    ]
    
    @State private var customSeparator = ""
    @State private var selectedOption = "New Line"
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Choose Separator for Bulk Paste")
                .font(.system(size: 16, weight: .semibold))
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(separatorOptions, id: \.0) { option in
                    HStack {
                        Button(action: {
                            selectedOption = option.0
                            if option.1 != "custom" {
                                separator = option.1
                            }
                        }) {
                            HStack {
                                Image(systemName: selectedOption == option.0 ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(selectedOption == option.0 ? .accentColor : .secondary)
                                Text(option.0)
                                    .font(.system(size: 14))
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                    }
                }
                
                if selectedOption == "Custom" {
                    TextField("Enter custom separator", text: $customSeparator)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: customSeparator) { value in
                            separator = value
                        }
                }
            }
            
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                
                Button("Paste") {
                    onPaste()
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(selectedOption == "Custom" && customSeparator.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

/// Custom button styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
    }
}
