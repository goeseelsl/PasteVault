import SwiftUI

/// Footer component showing item count and clear action
struct FooterView: View {
    let itemCount: Int
    let onClearAll: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(itemCount) items")
                .font(.system(size: 11, weight: .medium, design: .default))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Clear All") {
                onClearAll()
            }
            .font(.system(size: 11, weight: .medium, design: .default))
            .foregroundColor(.red)
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.red.opacity(isHovering ? 0.12 : 0.08))
            )
            .onHover { hovering in
                isHovering = hovering
            }
            .animation(.easeInOut(duration: 0.15), value: isHovering)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color(NSColor.windowBackgroundColor))
                .overlay(
                    Rectangle()
                        .fill(Color(NSColor.separatorColor))
                        .frame(height: 1),
                    alignment: .top
                )
        )
    }
}
