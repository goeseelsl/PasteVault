import Foundation
import CoreData

/// Helper for building Core Data predicates for content filtering
class ContentPredicateBuilder {
    
    /// Build predicate for filtering clipboard items
    /// - Parameters:
    ///   - searchText: The search text to filter by
    ///   - selectedFolder: The folder to filter by (optional)
    ///   - selectedSourceApp: The source app to filter by (optional)
    /// - Returns: A compound predicate for the search
    static func buildPredicate(searchText: String, selectedFolder: Folder?, selectedSourceApp: String? = nil) -> NSPredicate {
        let folderPredicate = selectedFolder == nil ? 
            NSPredicate(value: true) : 
            NSPredicate(format: "folder == %@", selectedFolder!)
        
        let sourceAppPredicate = selectedSourceApp == nil ?
            NSPredicate(value: true) :
            NSPredicate(format: "sourceApp == %@", selectedSourceApp!)
        
        var searchPredicate: NSPredicate
        
        if searchText.isEmpty {
            searchPredicate = NSPredicate(value: true)
        } else {
            searchPredicate = buildSearchPredicate(searchText: searchText)
        }
        
        return NSCompoundPredicate(andPredicateWithSubpredicates: [folderPredicate, sourceAppPredicate, searchPredicate])
    }
    
    /// Build search predicate based on search text
    /// - Parameter searchText: The search text
    /// - Returns: A predicate for searching content
    private static func buildSearchPredicate(searchText: String) -> NSPredicate {
        let searchLower = searchText.lowercased()
        
        // Enhanced search including content type filters
        switch searchLower {
        case "image", "images", "photo", "photos":
            return NSPredicate(format: "imageData != nil")
            
        case "url", "urls", "link", "links":
            return NSPredicate(format: "content CONTAINS[c] 'http' OR content CONTAINS[c] 'www' OR content CONTAINS[c] '://'")
            
        case "code", "programming", "script":
            return NSPredicate(format: "content CONTAINS[c] 'func' OR content CONTAINS[c] 'var' OR content CONTAINS[c] 'let' OR content CONTAINS[c] 'import' OR content CONTAINS[c] 'class' OR content CONTAINS[c] 'struct' OR content CONTAINS[c] 'def' OR content CONTAINS[c] 'function'")
            
        case "email", "emails", "mail":
            return NSPredicate(format: "content CONTAINS[c] '@' AND content CONTAINS[c] '.'")
            
        case "number", "numbers", "numeric":
            // This is a simplified check - for more accuracy, we'd need to do post-fetch filtering
            return NSPredicate(format: "content MATCHES '^[0-9]+\\.?[0-9]*$'")
            
        default:
            // Default search in content, source app, and category
            return NSPredicate(format: "content CONTAINS[c] %@ OR sourceApp CONTAINS[c] %@ OR category CONTAINS[c] %@", searchText, searchText, searchText)
        }
    }
    
    /// Filter results post-fetch for more accurate content type detection
    /// - Parameters:
    ///   - results: The Core Data results
    ///   - searchText: The original search text
    /// - Returns: Filtered results
    static func postFilterResults(_ results: [ClipboardItem], searchText: String) -> [ClipboardItem] {
        guard !searchText.isEmpty else { return results }
        
        let searchLower = searchText.lowercased()
        
        // Post-fetch filtering for more accurate content type detection
        if searchLower == "number" || searchLower == "numbers" || searchLower == "numeric" {
            return results.filter { item in
                guard let content = item.content else { return false }
                return ContentHelper.isNumber(content)
            }
        }
        
        return results
    }
}
