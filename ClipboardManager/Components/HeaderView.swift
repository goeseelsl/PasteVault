import SwiftUI

/// Header component for the clipboard manager
struct HeaderView: View {
    let onSettingsPressed: () -> Void
    let onOrganizePressed: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
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
