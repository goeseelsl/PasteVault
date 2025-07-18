import Foundation
import CryptoKit
import Security

class EncryptionManager {
    static let shared = EncryptionManager()
    
    private let keyTag = "com.clipboardmanager.encryption.key"
    private var symmetricKey: SymmetricKey?
    
    private init() {
        setupEncryptionKey()
    }
    
    // MARK: - Key Management
    
    private func setupEncryptionKey() {
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
    
    func encrypt(data: Data) -> Data? {
        guard let key = symmetricKey else {
            debugLog("No encryption key available")
            return nil
        }
        
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            return sealedBox.combined
        } catch {
            debugLog("Encryption failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    func decrypt(data: Data) -> Data? {
        guard let key = symmetricKey else {
            debugLog("No encryption key available")
            return nil
        }
        
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            debugLog("Decryption failed: \(error.localizedDescription)")
            return nil
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
