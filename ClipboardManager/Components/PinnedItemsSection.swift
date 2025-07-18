import SwiftUI
import CoreData

/// Dedicated section for pinned clipboard items
struct PinnedItemsSection: View {
    let pinnedItems: [ClipboardItem]
    let onUnpinItem: (ClipboardItem) -> Void
    let onPasteItem: (ClipboardItem) -> Void
    
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        if !pinnedItems.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                // Section header
                HStack(spacing: 8) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                    
                    Text("Pinned Items")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("(\(pinnedItems.count))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Manage pins button (for future feature)
                    if pinnedItems.count > 10 {
                        Button("Manage") {
                            // Future: Open manage pins sheet
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                
                // Pinned items display
                if pinnedItems.count <= 3 {
                    // Show all items without scrolling
                    VStack(spacing: 6) {
                        ForEach(pinnedItems, id: \.id) { item in
                            PinnedItemView(
                                item: item,
                                onUnpin: {
                                    onUnpinItem(item)
                                },
                                onPaste: {
                                    onPasteItem(item)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                } else {
                    // Scrollable horizontal layout for more than 3 items
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(pinnedItems, id: \.id) { item in
                                PinnedItemView(
                                    item: item,
                                    onUnpin: {
                                        onUnpinItem(item)
                                    },
                                    onPaste: {
                                        onPasteItem(item)
                                    }
                                )
                                .frame(width: 200) // Fixed width for carousel
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .frame(height: 60) // Fixed height for compact display
                    
                    // Scroll indicators for many items
                    if pinnedItems.count > 4 {
                        HStack {
                            Spacer()
                            Text("Scroll for more →")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.trailing, 16)
                        }
                    }
                }
                
                // Warning for many pinned items
                if pinnedItems.count > 10 {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        Text("You have many pinned items—consider managing them.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 12)
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal, 16)
        }
    }
}
