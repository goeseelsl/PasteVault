import SwiftUI

/// Header component for the clipboard manager
struct HeaderView: View {
    let onSettingsPressed: () -> Void
    let onOrganizePressed: () -> Void
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
            
            // Organize button
            Button(action: onOrganizePressed) {
                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Open Organization Window")
            .onHover { hovering in
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            
            Spacer()
            
            Button(action: onSettingsPressed) {
                Image(systemName: "gear")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { hovering in
                // Add subtle hover effect
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
