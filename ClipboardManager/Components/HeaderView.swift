import SwiftUI

/// Header component for the clipboard manager
struct HeaderView: View {
    let onSettingsPressed: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "doc.on.clipboard")
                .foregroundColor(.accentColor)
                .font(.system(size: 16, weight: .semibold))
            
            Text("Clipboard Manager")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: onSettingsPressed) {
                Image(systemName: "gear")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
    }
}
