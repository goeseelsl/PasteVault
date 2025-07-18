import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        let model = PersistenceController.createManagedObjectModel()
        container = NSPersistentCloudKitContainer(name: "ClipboardManager", managedObjectModel: model)
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        guard let description = container.persistentStoreDescriptions.first else {
            // Use proper error handling instead of fatalError
            print("❌ Failed to retrieve a persistent store description")
            return
        }
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // Enable CloudKit syncing
        description.setOption(true as NSNumber, forKey: "NSPersistentHistoryTrackingKey")
        description.setOption(true as NSNumber, forKey: "NSPersistentStoreRemoteChangeNotificationPostOptionKey")
        
        // Configure CloudKit container
        if let containerIdentifier = Bundle.main.object(forInfoDictionaryKey: "CloudKitContainerIdentifier") as? String {
            let cloudKitOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: containerIdentifier)
            description.cloudKitContainerOptions = cloudKitOptions
        }
        
        // Enable file protection on macOS - use NSFileProtectionComplete equivalent
        #if os(iOS)
        description.setOption(FileProtectionType.complete as NSString, forKey: NSPersistentStoreFileProtectionKey)
        #endif

        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Log the error instead of crashing
                print("❌ Core Data error: \(error.localizedDescription)")
                print("User info: \(error.userInfo)")
                // In a production app, you might want to show an alert to the user
                // or attempt recovery
            }
        })
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    static func createManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // Folder Entity
        let folderEntity = NSEntityDescription()
        folderEntity.name = "Folder"
        folderEntity.managedObjectClassName = "Folder"
        
        // CloudKit configuration for Folder
        folderEntity.userInfo = [
            "CloudKitRecordType": "Folder",
            "CloudKitRecordName": "id"
        ]
        
        let folderIdAttr = NSAttributeDescription()
        folderIdAttr.name = "id"
        folderIdAttr.attributeType = .UUIDAttributeType
        folderIdAttr.isOptional = false
        
        let folderNameAttr = NSAttributeDescription()
        folderNameAttr.name = "name"
        folderNameAttr.attributeType = .stringAttributeType
        folderNameAttr.isOptional = true
        
        let folderCreatedAtAttr = NSAttributeDescription()
        folderCreatedAtAttr.name = "createdAt"
        folderCreatedAtAttr.attributeType = .dateAttributeType
        folderCreatedAtAttr.isOptional = true
        
        // ClipboardItem Entity
        let itemEntity = NSEntityDescription()
        itemEntity.name = "ClipboardItem"
        itemEntity.managedObjectClassName = "ClipboardItem"
        
        // CloudKit configuration for ClipboardItem
        itemEntity.userInfo = [
            "CloudKitRecordType": "ClipboardItem",
            "CloudKitRecordName": "id"
        ]
        
        let itemIdAttr = NSAttributeDescription()
        itemIdAttr.name = "id"
        itemIdAttr.attributeType = .UUIDAttributeType
        itemIdAttr.isOptional = false
        
        let itemContentAttr = NSAttributeDescription()
        itemContentAttr.name = "content"
        itemContentAttr.attributeType = .stringAttributeType
        itemContentAttr.isOptional = true
        
        let itemCreatedAtAttr = NSAttributeDescription()
        itemCreatedAtAttr.name = "createdAt"
        itemCreatedAtAttr.attributeType = .dateAttributeType
        itemCreatedAtAttr.isOptional = true
        
        let itemSourceAppAttr = NSAttributeDescription()
        itemSourceAppAttr.name = "sourceApp"
        itemSourceAppAttr.attributeType = .stringAttributeType
        itemSourceAppAttr.isOptional = true
        
        let itemIsPinnedAttr = NSAttributeDescription()
        itemIsPinnedAttr.name = "isPinned"
        itemIsPinnedAttr.attributeType = .booleanAttributeType
        itemIsPinnedAttr.defaultValue = false
        
        let itemPinnedTimestampAttr = NSAttributeDescription()
        itemPinnedTimestampAttr.name = "pinnedTimestamp"
        itemPinnedTimestampAttr.attributeType = .dateAttributeType
        itemPinnedTimestampAttr.isOptional = true
        
        let itemIsFavoriteAttr = NSAttributeDescription()
        itemIsFavoriteAttr.name = "isFavorite"
        itemIsFavoriteAttr.attributeType = .booleanAttributeType
        itemIsFavoriteAttr.defaultValue = false
        
        let itemCategoryAttr = NSAttributeDescription()
        itemCategoryAttr.name = "category"
        itemCategoryAttr.attributeType = .stringAttributeType
        itemCategoryAttr.isOptional = true
        
        let itemImageDataAttr = NSAttributeDescription()
        itemImageDataAttr.name = "imageData"
        itemImageDataAttr.attributeType = .binaryDataAttributeType
        itemImageDataAttr.isOptional = true
        
        // Encrypted fields
        let itemEncryptedContentAttr = NSAttributeDescription()
        itemEncryptedContentAttr.name = "encryptedContent"
        itemEncryptedContentAttr.attributeType = .stringAttributeType
        itemEncryptedContentAttr.isOptional = true
        
        let itemEncryptedImageDataAttr = NSAttributeDescription()
        itemEncryptedImageDataAttr.name = "encryptedImageData"
        itemEncryptedImageDataAttr.attributeType = .binaryDataAttributeType
        itemEncryptedImageDataAttr.isOptional = true
        
        // Relationships
        let itemsRelationship = NSRelationshipDescription()
        itemsRelationship.name = "items"
        itemsRelationship.destinationEntity = itemEntity
        itemsRelationship.minCount = 0
        itemsRelationship.maxCount = 0 // To-many
        itemsRelationship.deleteRule = .cascadeDeleteRule
        
        let folderRelationship = NSRelationshipDescription()
        folderRelationship.name = "folder"
        folderRelationship.destinationEntity = folderEntity
        folderRelationship.minCount = 0
        folderRelationship.maxCount = 1 // To-one
        folderRelationship.deleteRule = .nullifyDeleteRule
        
        itemsRelationship.inverseRelationship = folderRelationship
        folderRelationship.inverseRelationship = itemsRelationship
        
        folderEntity.properties = [folderIdAttr, folderNameAttr, folderCreatedAtAttr, itemsRelationship]
        itemEntity.properties = [itemIdAttr, itemContentAttr, itemCreatedAtAttr, itemSourceAppAttr, itemIsPinnedAttr, itemPinnedTimestampAttr, itemIsFavoriteAttr, itemCategoryAttr, itemImageDataAttr, itemEncryptedContentAttr, itemEncryptedImageDataAttr, folderRelationship]
        
        model.entities = [folderEntity, itemEntity]
        
        return model
    }
}