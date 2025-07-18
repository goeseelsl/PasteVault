import SwiftUI

/// Footer component showing item count and actions
struct FooterView: View {
    let itemCount: Int
    let onSettingsPressed: () -> Void
    let onOrganizePressed: () -> Void
    let onClearPressed: () -> Void
    
    @State private var isHoveringClear = false
    @State private var isHoveringSettings = false
    @State private var isHoveringOrganize = false
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(itemCount) items")
                .font(.system(size: 11, weight: .medium, design: .default))
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Organize button
            Button("Organize") {
                onOrganizePressed()
            }
            .font(.system(size: 11, weight: .medium, design: .default))
            .foregroundColor(.blue)
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.blue.opacity(isHoveringOrganize ? 0.12 : 0.08))
            )
            .onHover { hovering in
                isHoveringOrganize = hovering
            }
            .animation(.easeInOut(duration: 0.15), value: isHoveringOrganize)
            
            // Settings button
            Button("Settings") {
                onSettingsPressed()
            }
            .font(.system(size: 11, weight: .medium, design: .default))
            .foregroundColor(.secondary)
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(isHoveringSettings ? 0.12 : 0.08))
            )
            .onHover { hovering in
                isHoveringSettings = hovering
            }
            .animation(.easeInOut(duration: 0.15), value: isHoveringSettings)
            
            Button("Clear All") {
                onClearPressed()
            }
            .font(.system(size: 11, weight: .medium, design: .default))
            .foregroundColor(.red)
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.red.opacity(isHoveringClear ? 0.12 : 0.08))
            )
            .onHover { hovering in
                isHoveringClear = hovering
            }
            .animation(.easeInOut(duration: 0.15), value: isHoveringClear)
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
