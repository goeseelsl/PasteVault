import SwiftUI
import CoreData
import Foundation

/// Enhanced clipboard card with improved content visualization
struct EnhancedClipboardCard: View {
    let item: ClipboardItem
    let isSelected: Bool
    let selectionIndex: Int
    let onToggleFavorite: () -> Void
    let onCopyToClipboard: () -> Void
    let onDeleteItem: () -> Void
    let onToggleSelection: () -> Void
    let onViewSource: () -> Void
    let onUndo: () -> Void
    let onEditText: () -> Void
    
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isHovered = false
    @State private var showSourceIcon = false
    @State private var showThumbnail = false
    
    // Fetch folders for the menu
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Folder.name, ascending: true)]
    ) private var folders: FetchedResults<Folder>
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with metadata
            HStack(spacing: 8) {
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 16))
                }
                
                // Source app icon
                InteractiveSourceIcon(item: item)
                
                // Type indicator
                Image(systemName: typeIcon)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                // Timestamp
                Text(formatTimestamp(item.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Pin button
                Button(action: {
                    item.isPinned.toggle()
                    try? viewContext.save()
                }) {
                    Image(systemName: item.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 14))
                        .foregroundColor(item.isPinned ? .orange : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .opacity(isHovered ? 1 : 0.7)
                
                // Favorite button
                Button(action: onToggleFavorite) {
                    Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 14))
                        .foregroundColor(item.isFavorite ? .red : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .opacity(isHovered ? 1 : 0.7)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            // Content preview
            VStack(alignment: .leading, spacing: 8) {
                if let content = item.content, !content.isEmpty {
                    Text(content)
                        .font(.system(size: 13))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            
            // Actions toolbar
            if isHovered {
                HStack(spacing: 8) {
                    Button("Copy", action: onCopyToClipboard)
                        .buttonStyle(PlainButtonStyle())
                        .font(.caption)
                    
                    Button("Delete", action: onDeleteItem)
                        .buttonStyle(PlainButtonStyle())
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    // Add to folder menu
                    Menu {
                        Button("Remove from folder") {
                            item.folder = nil
                            try? viewContext.save()
                        }
                        .disabled(item.folder == nil)
                        
                        if !folders.isEmpty {
                            Divider()
                            
                            ForEach(folders, id: \.self) { folder in
                                Button(folder.name ?? "Unnamed Folder") {
                                    item.folder = folder
                                    try? viewContext.save()
                                }
                                .disabled(item.folder == folder)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: item.folder != nil ? "folder.fill" : "folder")
                                .font(.system(size: 12))
                                .foregroundColor(item.folder != nil ? .blue : .secondary)
                            if let folderName = item.folder?.name {
                                Text(folderName)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onToggleSelection()
        }
    }
    
    private var typeIcon: String {
        guard let content = item.content else { return "doc.text" }
        
        if content.hasPrefix("http") || content.hasPrefix("https") {
            return "link"
        } else if content.contains("@") && content.contains(".") {
            return "envelope"
        } else if content.count > 100 {
            return "doc.text"
        } else {
            return "textformat"
        }
    }
    
    private func formatTimestamp(_ timestamp: Date?) -> String {
        guard let timestamp = timestamp else { return "" }
        
        let formatter = DateFormatter()
        let now = Date()
        let calendar = Calendar.current
        
        if calendar.isDate(timestamp, inSameDayAs: now) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: timestamp)
        } else if calendar.isDate(timestamp, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: now) ?? now) {
            return "Yesterday"
        } else if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now),
                  weekInterval.contains(timestamp) {
            formatter.dateFormat = "EEE"
            return formatter.string(from: timestamp)
        } else {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: timestamp)
        }
    }
}
