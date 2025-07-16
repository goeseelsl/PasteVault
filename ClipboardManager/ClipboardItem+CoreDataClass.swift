import Foundation
import CoreData
import AppKit

@objc(ClipboardItem)
public class ClipboardItem: NSManagedObject {
    
    // Cached image instances to prevent repeated processing - using weak references for memory efficiency
    internal lazy var imageCache = NSCache<NSString, NSImage>()
    
    // Efficient thumbnail generation with caching
    func thumbnail(size: CGFloat = 50) -> NSImage? {
        let cacheKey = "thumbnail_\(size)" as NSString
        
        if let cached = imageCache.object(forKey: cacheKey) {
            return cached
        }
        
        guard let fullImage = image else { return nil }
        
        let thumbnail = fullImage.thumbnail(size: size)
        
        // Cache the thumbnail for future use
        imageCache.setObject(thumbnail, forKey: cacheKey)
        
        return thumbnail
    }
    
    // Clear cached images when imageData changes
    func clearImageCache() {
        imageCache.removeAllObjects()
    }
    
    // Override awakeFromFetch to setup cache
    public override func awakeFromFetch() {
        super.awakeFromFetch()
        setupImageCache()
    }
    
    // Override awakeFromInsert to setup cache  
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        setupImageCache()
    }
    
    private func setupImageCache() {
        imageCache.countLimit = 5 // Limit cache size
        imageCache.totalCostLimit = 1024 * 1024 * 10 // 10MB limit
    }
}
