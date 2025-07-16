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

    // Unpersisted property for image preview with optimized caching
    var image: NSImage? {
        let cacheKey = "image" as NSString
        
        if let cached = imageCache.object(forKey: cacheKey) {
            return cached
        }
        
        guard let data = imageData else { return nil }
        
        // Create image on background queue to prevent UI blocking
        guard let image = NSImage(data: data) else { return nil }
        
        // Cache the image for future use
        imageCache.setObject(image, forKey: cacheKey)
        
        return image
    }
}

extension ClipboardItem : Identifiable {

}
