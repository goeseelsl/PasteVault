import SwiftUI

/// Settings window for configuring clipboard manager features
struct SettingsView: View {
    @StateObject private var appColorService = AppColorService.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var showingDebugLogs = false
    
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
                            
                            // Opacity Slider
                            if appColorService.isColorTintingEnabled {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Color Intensity")
                                            .font(.body)
                                            .padding(.horizontal)
                                        
                                        Spacer()
                                        
                                        Text("\(Int(appColorService.tintOpacity * 100))%")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal)
                                    }
                                    
                                    Slider(
                                        value: $appColorService.tintOpacity,
                                        in: 0.05...0.3,
                                        step: 0.01
                                    ) {
                                        Text("Opacity")
                                    }
                                    .padding(.horizontal)
                                    .onChange(of: appColorService.tintOpacity) { _ in
                                        appColorService.saveSettings()
                                    }
                                }
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
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Debug & Troubleshooting Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Debug & Troubleshooting")
                            .font(.headline)
                            .padding(.horizontal)
                            .foregroundColor(.red) // Make it more visible
                        
                        VStack(alignment: .leading, spacing: 12) {
                            // Debug Logs Button
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("View Debug Logs")
                                        .font(.body)
                                    Text("View detailed logs for paste operations and focus management")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button("View Logs") {
                                    showingDebugLogs = true
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.horizontal)
                            
                            // Clear Logs Button
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Clear Debug Logs")
                                        .font(.body)
                                    Text("Clear all stored debug information")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button("Clear") {
                                    PasteHelper.clearDebugLogs()
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .background(Color.yellow.opacity(0.3)) // Temporary background to make it visible
                }
                .padding(.vertical)
            }
        }
        .frame(width: 500, height: 700)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showingDebugLogs) {
            DebugLogsView()
        }
    }
    
    // MARK: - Helper Functions
    
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

/// Preview card component for demonstrating dynamic colors
private struct PreviewCard: View {
    let appName: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "app.fill")
                    .foregroundColor(.primary)
                    .font(.caption)
                
                Text(appName)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            Text("Sample clipboard content from \(appName)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(color)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
        )
        .frame(height: 50)
    }
}
