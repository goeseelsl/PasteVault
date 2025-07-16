import SwiftUI
import CoreData

/// Enhanced clipboard item card with rich previews and metadata
struct ClipboardNoteCard: View {
    @ObservedObject var item: ClipboardItem
    @Environment(\.managedObjectContext) private var viewContext
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Note-style card
            VStack(alignment: .leading, spacing: 10) {
                // Header with app and time
                HStack(spacing: 8) {
                    // Source app icon
                    HStack(spacing: 6) {
                        if let appIcon = AppIconHelper.shared.getAppIcon(for: item.sourceApp ?? "Unknown") {
                            Image(nsImage: appIcon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                                .cornerRadius(3)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                                )
                        } else {
                            // Fallback to colored circle if icon not available
                            Circle()
                                .fill(ColorHelper.colorForString(item.sourceApp ?? "Unknown"))
                                .frame(width: 12, height: 12)
                        }
                        
                        Text(item.sourceApp ?? "Unknown")
                            .font(.system(size: 11, weight: .medium, design: .default))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Status indicators
                    HStack(spacing: 4) {
                        if item.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.orange)
                        }
                        if item.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    Text(item.createdAt ?? Date(), style: .relative)
                        .font(.system(size: 10, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
                }
                
                // Enhanced Content preview with rich thumbnails
                HStack(alignment: .top, spacing: 12) {
                    // Enhanced preview thumbnail
                    contentThumbnail
                    
                    // Content text with enhanced formatting
                    VStack(alignment: .leading, spacing: 6) {
                        Text(contentPreview)
                            .font(.system(size: 12, weight: .regular, design: .default))
                            .lineLimit(3)
                            .lineSpacing(1.2)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Enhanced metadata with better spacing
                        HStack(spacing: 6) {
                            if let category = item.category {
                                Text(category)
                                    .font(.system(size: 9, weight: .medium, design: .default))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.secondary.opacity(0.12))
                                    )
                            }
                            
                            if let imageData = item.imageData, let image = NSImage(data: imageData) {
                                Text("\(Int(image.size.width))×\(Int(image.size.height))")
                                    .font(.system(size: 9, weight: .medium, design: .default))
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.blue.opacity(0.12))
                                    )
                            }
                            
                            Spacer()
                        }
                    }
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        isSelected ? 
                        Color.accentColor.opacity(0.15) : 
                        (isHovering ? Color(NSColor.controlBackgroundColor) : Color(NSColor.windowBackgroundColor))
                    )
                    .shadow(
                        color: isSelected ? Color.accentColor.opacity(0.25) : Color.black.opacity(0.06), 
                        radius: isSelected ? 6 : 2, 
                        x: 0, 
                        y: isSelected ? 2 : 1
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? 
                        Color.accentColor.opacity(0.4) : 
                        Color(NSColor.separatorColor).opacity(0.3), 
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
            .scaleEffect(isSelected ? 1.02 : (isHovering ? 1.005 : 1.0))
            .animation(.easeInOut(duration: 0.2), value: isSelected)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isSelected)
            .onTapGesture {
                onTap()
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 3)
    }
    
    // MARK: - Content Thumbnail
    
    @ViewBuilder
    private var contentThumbnail: some View {
        Group {
            if let thumbnailImage = item.thumbnail(size: 50) {
                // High-quality image thumbnail using cached thumbnail
                Image(nsImage: thumbnailImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipped()
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            } else if let content = item.content {
                contentTypeThumbnail(for: content)
            } else {
                defaultThumbnail
            }
        }
    }
    
    @ViewBuilder
    private func contentTypeThumbnail(for content: String) -> some View {
        let contentType = ContentHelper.getContentType(content)
        
        VStack(spacing: 3) {
            switch contentType {
            case "URL":
                Image(systemName: "link")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                Text("URL")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
            case "Code":
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                Text("CODE")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
            case "Email":
                Image(systemName: "envelope.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                Text("EMAIL")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
            case "Number":
                Image(systemName: "number")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                Text("NUM")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
            default:
                if !content.isEmpty {
                    Text(String(content.prefix(3)))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } else {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }
                Text("TEXT")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .frame(width: 50, height: 50)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ColorHelper.gradientForContentType(contentType))
        )
        .shadow(color: ColorHelper.colorForString(contentType).opacity(0.3), radius: 2, x: 0, y: 1)
    }
    
    @ViewBuilder
    private var defaultThumbnail: some View {
        VStack(spacing: 3) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white)
            Text("EMPTY")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(width: 50, height: 50)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ColorHelper.gradientForContentType("default"))
        )
        .shadow(color: .gray.opacity(0.3), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Content Preview
    
    private var contentPreview: String {
        if let content = item.content, !content.isEmpty {
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return "Empty content"
            }
            
            // Provide context-specific previews with emojis
            let emoji = ContentHelper.getContentEmoji(trimmed)
            
            if ContentHelper.isCode(trimmed) {
                // Show first meaningful line of code
                let lines = trimmed.components(separatedBy: .newlines)
                let meaningfulLine = lines.first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? trimmed
                return "\(emoji) \(meaningfulLine.prefix(50))\(meaningfulLine.count > 50 ? "..." : "")"
            } else {
                // Regular text with smart truncation
                return "\(emoji) \(trimmed.prefix(80))\(trimmed.count > 80 ? "..." : "")"
            }
        } else if item.imageData != nil {
            let imageSize = getImageSize()
            return "🖼️ Image \(imageSize)"
        } else {
            return "No content"
        }
    }
    
    private func getImageSize() -> String {
        guard let imageData = item.imageData,
              let image = NSImage(data: imageData) else {
            return ""
        }
        
        let size = image.size
        return "(\(Int(size.width))×\(Int(size.height)))"
    }
}
