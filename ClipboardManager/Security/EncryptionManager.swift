import Foundation
import CryptoKit
import Security

class EncryptionManager {
    static let shared = EncryptionManager()
    
    private let keyTag = "com.clipboardmanager.encryption.key"
    private var symmetricKey: SymmetricKey?
    private var isInitialized = false
    
    private init() {
        // Don't initialize encryption by default
        // Only initialize when explicitly requested (e.g., when iCloud sync is enabled)
        debugLog("EncryptionManager created - encryption disabled by default (no keychain access)")
    }
    
    // MARK: - Key Management
    
    func initializeEncryption() {
        guard !isInitialized else {
            debugLog("Encryption already initialized")
            return
        }
        
        setupEncryptionKey()
        isInitialized = true
    }
    
    private func setupEncryptionKey() {
        debugLog("Setting up encryption key from Keychain...")
        // Try to load existing key from Keychain
        if let existingKey = loadKeyFromKeychain() {
            self.symmetricKey = existingKey
            debugLog("Loaded existing encryption key from Keychain")
        } else {
            // Generate new key and save to Keychain
            let newKey = SymmetricKey(size: .bits256)
            saveKeyToKeychain(newKey)
            self.symmetricKey = newKey
            debugLog("Generated new encryption key and saved to Keychain")
        }
    }
    
    func disableEncryption() {
        symmetricKey = nil
        isInitialized = false
        debugLog("Encryption disabled")
    }
    
    private func saveKeyToKeychain(_ key: SymmetricKey) {
        let keyData = key.withUnsafeBytes { Data($0) }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyTag,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete any existing key
        SecItemDelete(query as CFDictionary)
        
        // Add new key
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            debugLog("Failed to save encryption key to Keychain: \(status)")
        }
    }
    
    private func loadKeyFromKeychain() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyTag,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let keyData = result as? Data else {
            return nil
        }
        
        return SymmetricKey(data: keyData)
    }
    
    // MARK: - Encryption/Decryption
    
    var isEncryptionEnabled: Bool {
        return isInitialized && symmetricKey != nil
    }
    
    func encrypt(data: Data) -> Data? {
        // If encryption is not enabled, return original data
        guard isEncryptionEnabled, let key = symmetricKey else {
            debugLog("Encryption not enabled - returning original data")
            return data
        }
        
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            return sealedBox.combined
        } catch {
            debugLog("Encryption failed: \(error.localizedDescription)")
            return data // Fallback to original data
        }
    }
    
    func decrypt(data: Data) -> Data? {
        // If encryption is not enabled, return original data
        guard isEncryptionEnabled, let key = symmetricKey else {
            debugLog("Encryption not enabled - returning original data")
            return data
        }
        
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            debugLog("Decryption failed (possibly unencrypted data): \(error.localizedDescription)")
            return data // Fallback to original data (for backwards compatibility)
        }
    }
    
    func encryptString(_ string: String) -> String? {
        guard let data = string.data(using: .utf8),
              let encryptedData = encrypt(data: data) else {
            return nil
        }
        
        return encryptedData.base64EncodedString()
    }
    
    func decryptString(_ encryptedString: String) -> String? {
        guard let encryptedData = Data(base64Encoded: encryptedString),
              let decryptedData = decrypt(data: encryptedData) else {
            return nil
        }
        
        return String(data: decryptedData, encoding: .utf8)
    }
    
    // MARK: - Image Encryption
    
    func encryptImage(_ imageData: Data) -> Data? {
        return encrypt(data: imageData)
    }
    
    func decryptImage(_ encryptedData: Data) -> Data? {
        return decrypt(data: encryptedData)
    }
    
    #if DEBUG
    private func debugLog(_ message: String) {
        print("🔐 [EncryptionManager] \(message)")
    }
    #else
    private func debugLog(_ message: String) { }
    #endif
}
