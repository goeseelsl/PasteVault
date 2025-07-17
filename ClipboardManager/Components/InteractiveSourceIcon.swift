import SwiftUI

/// Enhanced interactive source icon with tooltips and actions
struct InteractiveSourceIcon: View {
    let item: ClipboardItem
    @State private var isHovering = false
    @State private var showTooltip = false
    @State private var showActions = false
    
    var body: some View {
        Group {
            if let appIcon = AppIconHelper.shared.getAppIcon(for: item.sourceApp ?? "Unknown") {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .cornerRadius(3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                    )
                    .scaleEffect(isHovering ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: isHovering)
            } else {
                Circle()
                    .fill(ColorHelper.colorForString(item.sourceApp ?? "Unknown"))
                    .frame(width: 12, height: 12)
                    .scaleEffect(isHovering ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: isHovering)
            }
        }
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                showTooltip = true
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if !isHovering {
                        showTooltip = false
                    }
                }
            }
        }
        .onTapGesture {
            handleIconTap()
        }
        .contextMenu {
            SourceIconContextMenu(item: item)
        }
        .overlay(
            sourceTooltip,
            alignment: .topTrailing
        )
    }
    
    @ViewBuilder
    private var sourceTooltip: some View {
        if showTooltip {
            SourceTooltipView(item: item)
                .offset(x: 10, y: -10)
                .zIndex(1000)
        }
    }
    
    private func handleIconTap() {
        guard let sourceApp = item.sourceApp else { return }
        let appInfo = AppIconHelper.shared.getAppInfo(for: sourceApp)
        
        // Try to launch or activate the app
        if AppIconHelper.shared.launchApp(bundleIdentifier: appInfo.bundleIdentifier) {
            // Optionally, try to open with content
            if let content = item.content {
                _ = AppIconHelper.shared.openInApp(bundleIdentifier: appInfo.bundleIdentifier, content: content)
            }
        }
    }
}

/// Source tooltip view
struct SourceTooltipView: View {
    let item: ClipboardItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let appIcon = AppIconHelper.shared.getAppIcon(for: item.sourceApp ?? "Unknown") {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .cornerRadius(4)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.sourceApp ?? "Unknown")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    let appInfo = AppIconHelper.shared.getAppInfo(for: item.sourceApp ?? "Unknown")
                    Text(appInfo.isRunning ? "Currently running" : "Not running")
                        .font(.system(size: 10))
                        .foregroundColor(appInfo.isRunning ? .green : .secondary)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Copied: \(item.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown")")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                if let content = item.content {
                    Text("Content: \(content.prefix(50))\(content.count > 50 ? "..." : "")")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Divider()
            
            Text("Click to launch app • Right-click for options")
                .font(.system(size: 9))
                .foregroundColor(Color(.tertiaryLabelColor))
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
        .frame(maxWidth: 200)
    }
}

/// Context menu for source icon
struct SourceIconContextMenu: View {
    let item: ClipboardItem
    
    var body: some View {
        let appInfo = AppIconHelper.shared.getAppInfo(for: item.sourceApp ?? "Unknown")
        
        Group {
            Button("Launch \(appInfo.name)") {
                _ = AppIconHelper.shared.launchApp(bundleIdentifier: appInfo.bundleIdentifier)
            }
            
            if let content = item.content, !content.isEmpty {
                Button("Open with \(appInfo.name)") {
                    _ = AppIconHelper.shared.openInApp(bundleIdentifier: appInfo.bundleIdentifier, content: content)
                }
            }
            
            Divider()
            
            Button("Filter by \(appInfo.name)") {
                // This would trigger filtering by this app
                NotificationCenter.default.post(
                    name: .filterBySourceApp,
                    object: appInfo.name
                )
            }
            
            Button("Hide items from \(appInfo.name)") {
                // This would add the app to ignored list
                NotificationCenter.default.post(
                    name: .ignoreSourceApp,
                    object: appInfo.bundleIdentifier
                )
            }
            
            Divider()
            
            Button("App Info") {
                showAppInfo(appInfo)
            }
        }
    }
    
    private func showAppInfo(_ appInfo: AppInfo) {
        let alert = NSAlert()
        alert.messageText = "App Information"
        alert.informativeText = """
        Name: \(appInfo.name)
        Bundle ID: \(appInfo.bundleIdentifier)
        Status: \(appInfo.isRunning ? "Running" : "Not running")
        """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let filterBySourceApp = Notification.Name("filterBySourceApp")
    static let ignoreSourceApp = Notification.Name("ignoreSourceApp")
}
