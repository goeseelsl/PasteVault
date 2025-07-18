import SwiftUI
import CoreData

/// Compact view for pinned items in the pinned section
struct PinnedItemView: View {
    let item: ClipboardItem
    let onUnpin: () -> Void
    let onPaste: () -> Void
    
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Content preview
            VStack(alignment: .leading, spacing: 4) {
                // Source app and content preview
                HStack(spacing: 6) {
                    // Source icon (smaller)
                    if let sourceApp = item.sourceApp {
                        Image(systemName: sourceIconName(for: sourceApp))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    // Content preview
                    if let imageData = item.decryptedImageData, let nsImage = NSImage(data: imageData) {
                        // Image thumbnail
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 24, height: 24)
                            .cornerRadius(4)
                            .clipped()
                        
                        Text("Image \(Int(nsImage.size.width))×\(Int(nsImage.size.height))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else if let content = item.decryptedContent, !content.isEmpty {
                        Text(content)
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                }
                
                // Timestamp
                if let pinnedTime = item.pinnedTimestamp {
                    Text("Pinned \(formatRelativeTime(pinnedTime))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Unpin button (only shown on hover)
            if isHovered {
                Button(action: onUnpin) {
                    Image(systemName: "pin.slash")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.blue.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onPaste()
        }
    }
    
    private func sourceIconName(for sourceApp: String) -> String {
        switch sourceApp.lowercased() {
        case "finder": return "folder"
        case "safari": return "safari"
        case "chrome", "google chrome": return "globe"
        case "xcode": return "hammer"
        case "notes": return "note.text"
        case "messages": return "message"
        case "mail": return "envelope"
        case "terminal": return "terminal"
        case "textedit": return "doc.text"
        default: return "app"
        }
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
