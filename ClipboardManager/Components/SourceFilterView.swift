import SwiftUI

/// Source app filter view for organizing clipboard items by source application
struct SourceFilterView: View {
    let sourceApps: [String]
    @Binding var selectedSourceApp: String?
    @Binding var showSourceFilter: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // Toggle button for source filter
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSourceFilter.toggle()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "app.badge")
                            .font(.system(size: 12, weight: .medium))
                        Text("Source Apps")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: showSourceFilter ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Clear filter button
                if selectedSourceApp != nil {
                    Button(action: {
                        selectedSourceApp = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Source apps grid
            if showSourceFilter {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(sourceApps, id: \.self) { app in
                            SourceAppChip(
                                app: app,
                                isSelected: selectedSourceApp == app,
                                onTap: {
                                    selectedSourceApp = selectedSourceApp == app ? nil : app
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

/// Individual source app chip component
struct SourceAppChip: View {
    let app: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                // App icon
                if let appIcon = AppIconHelper.shared.getAppIcon(for: app) {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .cornerRadius(3)
                } else {
                    Circle()
                        .fill(ColorHelper.colorForString(app))
                        .frame(width: 12, height: 12)
                }
                
                Text(app)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isSelected ? 
                        Color.accentColor.opacity(0.2) : 
                        Color(NSColor.windowBackgroundColor)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? 
                        Color.accentColor : 
                        Color(NSColor.separatorColor),
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
            .foregroundColor(isSelected ? .accentColor : .primary)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

#Preview {
    SourceFilterView(
        sourceApps: ["Safari", "Notes", "Xcode", "Terminal", "Messages"],
        selectedSourceApp: .constant("Safari"),
        showSourceFilter: .constant(true)
    )
    .frame(width: 400)
}
