import SwiftUI

/// Settings window for configuring clipboard manager features
struct SettingsView: View {
    @StateObject private var appColorService = AppColorService.shared
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.return)
            }
            .padding()
            
            Divider()
            
            // Settings content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Visual Features Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Visual Features")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            // Color Tinting Toggle
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Dynamic Background Colors")
                                        .font(.body)
                                    Text("Add subtle background colors to items based on their source app")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: $appColorService.isColorTintingEnabled)
                                    .onChange(of: appColorService.isColorTintingEnabled) { _ in
                                        appColorService.saveSettings()
                                    }
                            }
                            .padding(.horizontal)
                            
                            // Opacity Slider (only shown when tinting is enabled)
                            if appColorService.isColorTintingEnabled {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Color Intensity")
                                            .font(.body)
                                        Spacer()
                                        Text("\(Int(appColorService.tintOpacity * 100))%")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Slider(
                                        value: $appColorService.tintOpacity,
                                        in: 0.05...0.3,
                                        step: 0.01
                                    ) {
                                        Text("Opacity")
                                    }
                                    .onChange(of: appColorService.tintOpacity) { _ in
                                        appColorService.saveSettings()
                                    }
                                }
                                .padding(.horizontal)
                                .transition(.opacity)
                            }
                            
                            // Preview Section
                            if appColorService.isColorTintingEnabled {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Preview")
                                        .font(.body)
                                        .padding(.horizontal)
                                    
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                        ForEach(previewApps, id: \.name) { app in
                                            PreviewCard(appName: app.name, color: app.color)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                                .transition(.opacity)
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: appColorService.isColorTintingEnabled)
                    }
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Cache Management Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Performance")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Clear Color Cache")
                                    .font(.body)
                                Text("Reset cached app colors to refresh color extraction")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Clear Cache") {
                                appColorService.clearCache()
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.vertical)
            }
        }
        .frame(width: 500, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // Preview data for different apps
    private var previewApps: [(name: String, color: Color)] {
        [
            ("Visual Studio Code", Color.blue.opacity(appColorService.tintOpacity)),
            ("Safari", Color.blue.opacity(appColorService.tintOpacity)),
            ("Mail", Color.orange.opacity(appColorService.tintOpacity)),
            ("Notes", Color.yellow.opacity(appColorService.tintOpacity)),
            ("Terminal", Color.black.opacity(appColorService.tintOpacity)),
            ("Chrome", Color.red.opacity(appColorService.tintOpacity))
        ]
    }
}

/// Preview card for showing app color tinting
struct PreviewCard: View {
    let appName: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            // App icon placeholder
            Image(systemName: iconName)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(appName)
                    .font(.caption)
                    .lineLimit(1)
                Text("Sample content...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(color)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var iconName: String {
        switch appName.lowercased() {
        case let name where name.contains("visual studio"):
            return "hammer"
        case let name where name.contains("safari"):
            return "safari"
        case let name where name.contains("mail"):
            return "envelope"
        case let name where name.contains("notes"):
            return "note.text"
        case let name where name.contains("terminal"):
            return "terminal"
        case let name where name.contains("chrome"):
            return "globe"
        default:
            return "app"
        }
    }
}

#Preview {
    SettingsView()
}