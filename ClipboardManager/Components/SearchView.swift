import SwiftUI

/// Search bar component for filtering clipboard items
struct SearchView: View {
    @Binding var searchText: String
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 12, weight: .medium))
            
            TextField("Search clipboard... (try: image, url, code, email, number)", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 12, weight: .regular, design: .default))
                .foregroundColor(.primary)
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(isHovering ? .gray : .secondary)
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { hovering in
                    isHovering = hovering
                }
            }
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
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
    }
}
