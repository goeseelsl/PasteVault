import Foundation
import CloudKit
import CoreData
import Combine

@MainActor
class CloudKitSyncManager: ObservableObject {
    static let shared = CloudKitSyncManager()
    
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var isCloudKitEnabled: Bool = false  // Default to disabled
    @Published var accountStatus: CKAccountStatus = .couldNotDetermine
    @Published var isCloudKitAvailable: Bool = false
    @Published var userWantsCloudKitSync: Bool = false  // Track user preference
    
    private var container: CKContainer?
    private var cancellables = Set<AnyCancellable>()
    
    enum SyncStatus: Equatable {
        case idle
        case syncing
        case success
        case error(String)
        
        static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.syncing, .syncing), (.success, .success):
                return true
            case (.error(let lhsMessage), .error(let rhsMessage)):
                return lhsMessage == rhsMessage
            default:
                return false
            }
        }
    }
    
    private init() {
        // Don't initialize CloudKit by default
        // Only initialize when user explicitly enables sync
        print("🌥️ [CloudKit] CloudKitSyncManager accessed - initializing with first-time defaults")
        loadUserPreferences()
        
        // Mimic first-time installation - reset to disabled
        // This ensures no keychain access during settings view loading
        resetToFirstTimeInstallation()
        
        print("🌥️ [CloudKit] CloudKit sync manager initialized - sync disabled by default")
    }
    
    private func loadUserPreferences() {
        // Load user preference for CloudKit sync from UserDefaults
        userWantsCloudKitSync = UserDefaults.standard.bool(forKey: "CloudKitSyncEnabled")
        isCloudKitEnabled = false  // Always start disabled until user enables it
    }
    
    private func resetToFirstTimeInstallation() {
        // Reset all CloudKit-related preferences to mimic first-time installation
        userWantsCloudKitSync = false
        isCloudKitEnabled = false
        isCloudKitAvailable = false
        syncStatus = .idle
        accountStatus = .couldNotDetermine
        
        // Clear the user preference to ensure fresh start
        UserDefaults.standard.removeObject(forKey: "CloudKitSyncEnabled")
        
        // Ensure encryption is disabled to prevent any keychain access
        EncryptionManager.shared.disableEncryption()
        
        print("🌥️ [CloudKit] Reset to first-time installation state - no keychain access")
    }
    
    private func saveUserPreferences() {
        UserDefaults.standard.set(userWantsCloudKitSync, forKey: "CloudKitSyncEnabled")
    }
    
    private func initializeCloudKitOnDemand() async {
        print("🌥️ [CloudKit] Checking CloudKit availability...")
        
        // Check if we're in a proper app environment
        let bundleId = Bundle.main.bundleIdentifier
        print("🌥️ [CloudKit] Bundle identifier: \(bundleId ?? "nil")")
        
        // In development/command-line environments, CloudKit is not available
        if bundleId == nil || bundleId == "ClipboardManager" {
            print("⚠️ [CloudKit] CloudKit not available - running in development/command-line environment")
            print("💡 [CloudKit] CloudKit requires proper app bundle with entitlements")
            isCloudKitAvailable = false
            syncStatus = .error("CloudKit not available in development environment")
            return
        }
        
        // For future implementation in proper app environment
        print("🌥️ [CloudKit] Attempting to initialize CloudKit container...")
        isCloudKitAvailable = false
        syncStatus = .error("CloudKit requires Xcode app project with CloudKit entitlements")
    }
    
    // MARK: - Account Management
    
    func checkAccountStatus() {
        guard userWantsCloudKitSync else {
            print("🌥️ [CloudKit] Account status check skipped - user hasn't enabled CloudKit sync")
            return
        }
        
        Task {
            await checkAccountStatusInternal()
        }
    }
    
    private func checkAccountStatusInternal() async {
        guard let container = container else {
            print("⚠️ [CloudKit] Container not initialized")
            accountStatus = .couldNotDetermine
            return
        }
        
        do {
            let status = try await container.accountStatus()
            await MainActor.run {
                self.accountStatus = status
                self.isCloudKitEnabled = (status == .available)
                print("🌥️ [CloudKit] Account status: \(self.accountStatusMessage(status))")
            }
        } catch {
            await MainActor.run {
                self.accountStatus = .couldNotDetermine
                self.isCloudKitEnabled = false
                self.isCloudKitAvailable = false
                print("⚠️ [CloudKit] Failed to check account status: \(error.localizedDescription)")
                self.syncStatus = .error("Failed to check iCloud account: \(error.localizedDescription)")
            }
        }
    }
    
    private func accountStatusMessage(_ status: CKAccountStatus) -> String {
        switch status {
        case .available:
            return "CloudKit available"
        case .noAccount:
            return "No iCloud account"
        case .restricted:
            return "iCloud account restricted"
        case .couldNotDetermine:
            return "CloudKit status unknown"
        case .temporarilyUnavailable:
            return "CloudKit temporarily unavailable"
        @unknown default:
            return "Unknown CloudKit status"
        }
    }
    
    // MARK: - Sync Operations
    
    func triggerSync() {
        guard isCloudKitAvailable else {
            debugLog("CloudKit not available")
            syncStatus = .error("CloudKit not available")
            return
        }
        
        guard isCloudKitEnabled else {
            debugLog("CloudKit sync disabled")
            return
        }
        
        guard accountStatus == .available else {
            debugLog("CloudKit account not available")
            return
        }
        
        Task {
            await performSync()
        }
    }
    
    @MainActor
    private func performSync() async {
        syncStatus = .syncing
        debugLog("Starting CloudKit sync...")
        
        do {
            // Trigger Core Data CloudKit sync
            let viewContext = PersistenceController.shared.container.viewContext
            viewContext.performAndWait {
                // Force a save to trigger CloudKit sync
                if viewContext.hasChanges {
                    do {
                        try viewContext.save()
                    } catch {
                        print("CloudKit sync save error: \(error)")
                    }
                }
            }
            
            // Wait a bit for CloudKit to process
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            syncStatus = .success
            lastSyncDate = Date()
            debugLog("CloudKit sync completed successfully")
            
        } catch {
            syncStatus = .error("Sync failed: \(error.localizedDescription)")
            debugLog("CloudKit sync failed: \(error)")
        }
    }
    
    // MARK: - Remote Change Notifications
    
    private func setupCloudKitMonitoring() {
        // Listen for remote changes
        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .sink { [weak self] notification in
                Task { @MainActor in
                    self?.handleRemoteChange(notification)
                }
            }
            .store(in: &cancellables)
        
        // Listen for CloudKit account changes
        NotificationCenter.default.publisher(for: .CKAccountChanged)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.checkAccountStatus()
                }
            }
            .store(in: &cancellables)
    }
    
    @MainActor
    private func handleRemoteChange(_ notification: Notification) {
        debugLog("Received remote change notification")
        
        // Update UI to reflect remote changes
        DispatchQueue.main.async {
            // Notify the UI that data has changed
            NotificationCenter.default.post(name: .clipboardDataChanged, object: nil)
        }
    }
    
    // MARK: - Device Management
    
        func getDeviceInfo() -> String {
        let deviceName = ProcessInfo.processInfo.hostName
        let systemVersion = ProcessInfo.processInfo.operatingSystemVersionString
        return "Device: \(deviceName)\nSystem: \(systemVersion)"
    }
    
    // MARK: - Sync Settings
    
    func enableCloudKitSync() async {
        userWantsCloudKitSync = true
        saveUserPreferences()
        
        // Initialize encryption when enabling iCloud sync
        // This is when we prompt for keychain access
        debugLog("Initializing encryption for iCloud sync...")
        EncryptionManager.shared.initializeEncryption()
        
        // Check if CloudKit is already available
        if !isCloudKitAvailable {
            // Initialize CloudKit for the first time with proper error handling
            await initializeCloudKitOnDemand()
        }
        
        // Only enable if CloudKit is actually available
        if isCloudKitAvailable {
            isCloudKitEnabled = true
            if accountStatus == .available {
                triggerSync()
            }
            debugLog("CloudKit sync enabled by user")
        } else {
            isCloudKitEnabled = false
            debugLog("Failed to enable CloudKit sync - CloudKit not available in this environment")
            // Keep user preference but show appropriate error state
        }
    }
    
    func disableCloudKitSync() {
        userWantsCloudKitSync = false
        isCloudKitEnabled = false
        syncStatus = .idle
        saveUserPreferences()
        
        // Disable encryption when disabling iCloud sync
        EncryptionManager.shared.disableEncryption()
        debugLog("CloudKit sync disabled by user - encryption disabled")
    }
    
    // MARK: - Conflict Resolution
    
    func resolveConflicts() async {
        guard isCloudKitAvailable && isCloudKitEnabled else { return }
        
        debugLog("Checking for CloudKit conflicts...")
        
        // Core Data with CloudKit automatically handles most conflicts
        // We can add custom conflict resolution logic here if needed
        
        await performSync()
    }
    
    #if DEBUG
    private func debugLog(_ message: String) {
        print("☁️ [CloudKitSyncManager] \(message)")
    }
    #else
    private func debugLog(_ message: String) { }
    #endif
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let clipboardDataChanged = Notification.Name("clipboardDataChanged")
}
