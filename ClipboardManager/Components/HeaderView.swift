import SwiftUI

/// Header component for the clipboard manager
struct HeaderView: View {
    let onToggleSidebar: () -> Void
    let isSidebarVisible: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            // Sidebar toggle button
            Button(action: onToggleSidebar) {
                Image(systemName: isSidebarVisible ? "sidebar.left" : "sidebar.left.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .help(isSidebarVisible ? "Hide Sidebar" : "Show Sidebar")
            .onHover { hovering in
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
