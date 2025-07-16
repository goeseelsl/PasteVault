import Foundation
import CoreData

public extension Folder {

    @nonobjc class func fetchRequest() -> NSFetchRequest<Folder> {
        return NSFetchRequest<Folder>(entityName: "Folder")
    }

    @NSManaged var id: UUID?
    @NSManaged var name: String?
    @NSManaged var createdAt: Date?
    @NSManaged var items: NSSet?

}

// MARK: Generated accessors for items
extension Folder {

    @objc(addItemsObject:)
    @NSManaged public func addToItems(_ value: ClipboardItem)

    @objc(removeItemsObject:)
    @NSManaged public func removeFromItems(_ value: ClipboardItem)

    @objc(addItems:)
    @NSManaged public func addToItems(_ values: NSSet)

    @objc(removeItems:)
    @NSManaged public func removeFromItems(_ values: NSSet)

}

extension Folder : Identifiable {

}
