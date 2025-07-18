import Foundation
import CoreData
import AppKit

@objc(ClipboardItem)
public class ClipboardItem: NSManagedObject {
    // Image cache for performance
    static let imageCache = NSCache<NSString, NSImage>()
}
