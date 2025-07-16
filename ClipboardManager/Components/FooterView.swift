import SwiftUI

/// Footer component showing item count and clear action
struct FooterView: View {
    let itemCount: Int
    let onClearAll: () -> Void
    
    var body: some View {
        HStack {
            Text("\(itemCount) items")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Clear All") {
                onClearAll()
            }
            .font(.system(size: 10))
            .foregroundColor(.red)
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
    }
}
