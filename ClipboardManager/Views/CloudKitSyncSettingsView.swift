import SwiftUI
import CloudKit

struct CloudKitSyncSettingsView: View {
    @ObservedObject private var syncManager = CloudKitSyncManager.shared
    @State private var showingAccountAlert = false
    @State private var showingEnableSyncAlert = false
    @State private var isEnablingSync = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "icloud")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("iCloud Sync")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            // Main content based on sync state
            if !syncManager.userWantsCloudKitSync {
                cloudKitDisabledContent
            } else if !syncManager.isCloudKitAvailable {
                cloudKitUnavailableContent
            } else {
                cloudKitEnabledContent
            }
        }
        .padding()
        .frame(maxWidth: 400)
        .alert("Enable iCloud Sync?", isPresented: $showingEnableSyncAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Enable") {
                enableiCloudSync()
            }
        } message: {
            Text("This will enable iCloud synchronization for your clipboard history using your iCloud account credentials stored in the system keychain. Your clipboard data will be encrypted and synced across all your devices signed in to the same iCloud account.")
        }
        .alert("iCloud Account Required", isPresented: $showingAccountAlert) {
            Button("OK") { }
        } message: {
            Text("Please sign in to iCloud in System Preferences to enable clipboard sync.")
        }
    }
    
    @ViewBuilder
    private var cloudKitDisabledContent: some View {
        VStack(spacing: 20) {
            // Sync disabled state
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "icloud.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("iCloud Sync Disabled")
                            .font(.headline)
                        Text("Your clipboard history is stored locally only")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Benefits of iCloud Sync:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Label("Access clipboard history on all your devices", systemImage: "devices")
                        .font(.caption)
                    Label("Automatic encrypted backup of your clipboard data", systemImage: "lock.icloud")
                        .font(.caption)
                    Label("Seamless synchronization across Mac, iPhone, iPad", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                    Label("Uses your existing iCloud account for secure authentication", systemImage: "person.badge.key")
                        .font(.caption)
                }
                
                Button(action: {
                    showingEnableSyncAlert = true
                }) {
                    HStack {
                        Image(systemName: "icloud")
                        Text("Enable iCloud Sync")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isEnablingSync)
                
                if isEnablingSync {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Setting up iCloud sync...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private var cloudKitUnavailableContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                Text("iCloud Sync Unavailable")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            
            Text("iCloud sync is currently unavailable. This may be due to:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("• Running from command line instead of Xcode")
                Text("• Missing Apple Developer account configuration")
                Text("• Network connectivity issues")
                Text("• iCloud account not signed in")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.leading)
            
            Button("Retry iCloud Setup") {
                enableiCloudSync()
            }
            .disabled(isEnablingSync)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private var cloudKitEnabledContent: some View {
        VStack(spacing: 20) {
            
            // Account Status
            VStack(alignment: .leading, spacing: 8) {
                Text("iCloud Account Status")
                    .font(.headline)
                
                HStack {
                    Circle()
                        .fill(accountStatusColor)
                        .frame(width: 8, height: 8)
                    
                    Text(accountStatusText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            // Sync Control
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Clipboard History Sync")
                        .font(.headline)
                    
                    Spacer()
                    
                    Toggle("", isOn: .constant(true))
                        .toggleStyle(SwitchToggleStyle())
                        .disabled(true)  // Always on when in this view
                }
                
                HStack {
                    Text("✅ iCloud sync is enabled")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Spacer()
                    
                    Button("Disable Sync") {
                        syncManager.disableCloudKitSync()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            // Sync Status
            VStack(alignment: .leading, spacing: 8) {
                Text("Sync Status")
                    .font(.headline)
                
                HStack {
                    syncStatusIcon
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(syncStatusText)
                            .font(.subheadline)
                        
                        if let lastSync = syncManager.lastSyncDate {
                            Text("Last synced: \(lastSync, formatter: dateFormatter)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if case .syncing = syncManager.syncStatus {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                
                if syncManager.accountStatus == .available {
                    Button("Sync Now") {
                        syncManager.triggerSync()
                    }
                    .buttonStyle(.bordered)
                    .disabled(syncManager.syncStatus == .syncing)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            Spacer()
        }
    }
    
    // MARK: - Helper Methods
    
    private func enableiCloudSync() {
        isEnablingSync = true
        
        Task {
            await syncManager.enableCloudKitSync()
            await MainActor.run {
                isEnablingSync = false
                
                // Show account alert if needed
                if syncManager.accountStatus != .available && syncManager.isCloudKitAvailable {
                    showingAccountAlert = true
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var accountStatusColor: Color {
        switch syncManager.accountStatus {
        case .available:
            return .green
        case .noAccount, .restricted:
            return .red
        case .couldNotDetermine, .temporarilyUnavailable:
            return .orange
        @unknown default:
            return .gray
        }
    }
    
    private var accountStatusText: String {
        switch syncManager.accountStatus {
        case .available:
            return "Signed in to iCloud"
        case .noAccount:
            return "No iCloud account - Please sign in to iCloud in System Preferences"
        case .restricted:
            return "iCloud account restricted"
        case .couldNotDetermine:
            return "Checking iCloud status..."
        case .temporarilyUnavailable:
            return "iCloud temporarily unavailable"
        @unknown default:
            return "Unknown status"
        }
    }
    
    private var syncStatusIcon: some View {
        Group {
            switch syncManager.syncStatus {
            case .idle:
                Image(systemName: "cloud")
                    .foregroundColor(.secondary)
            case .syncing:
                Image(systemName: "cloud.fill")
                    .foregroundColor(.blue)
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .error:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            }
        }
    }
    
    private var syncStatusText: String {
        switch syncManager.syncStatus {
        case .idle:
            return "Ready to sync"
        case .syncing:
            return "Syncing..."
        case .success:
            return "Sync completed successfully"
        case .error(let message):
            return "Sync failed: \(message)"
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
}

struct CloudKitSyncSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        CloudKitSyncSettingsView()
    }
}
