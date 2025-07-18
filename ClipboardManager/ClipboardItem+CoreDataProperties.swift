import Foundation
import CoreData
import AppKit

extension ClipboardItem {

    @nonobjc class func fetchRequest() -> NSFetchRequest<ClipboardItem> {
        return NSFetchRequest<ClipboardItem>(entityName: "ClipboardItem")
    }

    @NSManaged public var id: UUID?
    @NSManaged var content: String?
    @NSManaged var createdAt: Date?
    @NSManaged var sourceApp: String?
    @NSManaged var isPinned: Bool
    @NSManaged var isFavorite: Bool
    @NSManaged var category: String?
    @NSManaged var imageData: Data?
    @NSManaged var folder: Folder?
    
    // Encrypted fields
    @NSManaged var encryptedContent: String?
    @NSManaged var encryptedImageData: Data?
    
    // Computed properties for decrypted data
    var decryptedContent: String? {
        get {
            if let encryptedContent = encryptedContent {
                return EncryptionManager.shared.decryptString(encryptedContent)
            }
            return content // Fallback for legacy items
        }
        set {
            if let newValue = newValue {
                encryptedContent = EncryptionManager.shared.encryptString(newValue)
                content = nil // Clear plaintext
            } else {
                encryptedContent = nil
                content = nil
            }
        }
    }
    
    var decryptedImageData: Data? {
        get {
            if let encryptedImageData = encryptedImageData {
                return EncryptionManager.shared.decryptImage(encryptedImageData)
            }
            return imageData // Fallback for legacy items
        }
        set {
            if let newValue = newValue {
                encryptedImageData = EncryptionManager.shared.encryptImage(newValue)
                imageData = nil // Clear plaintext
            } else {
                encryptedImageData = nil
                imageData = nil
            }
        }
    }

    // Unpersisted property for image preview with optimized caching
    var image: NSImage? {
        let cacheKey = "image" as NSString
        
        if let cached = imageCache.object(forKey: cacheKey) {
            return cached
        }
        
        // Use decrypted image data
        guard let data = decryptedImageData else { return nil }
        
        // Create image on background queue to prevent UI blocking
        guard let image = NSImage(data: data) else { return nil }
        
        // Cache the image for future use
        imageCache.setObject(image, forKey: cacheKey)
        
        return image
    }
}

extension ClipboardItem : Identifiable {

}
