import SwiftUI

/// Header component for the clipboard manager
struct HeaderView: View {
    let onSettingsPressed: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .foregroundColor(.accentColor)
                .font(.system(size: 16, weight: .semibold, design: .default))
            
            Text("Clipboard Manager")
                .font(.system(size: 14, weight: .semibold, design: .default))
                .foregroundColor(.primary)
            
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
        .padding(.vertical, 12)
    }
}
