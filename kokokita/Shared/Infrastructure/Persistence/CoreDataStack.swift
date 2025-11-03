import CoreData

final class CoreDataStack {
    static let shared = CoreDataStack()
    let container: NSPersistentContainer

    init(modelName: String = "Kokokita") {
        container = NSPersistentContainer(name: modelName)

        // 軽量マイグレーションを有効化
        if let desc = container.persistentStoreDescriptions.first {
            desc.shouldInferMappingModelAutomatically = true
            desc.shouldMigrateStoreAutomatically = true
        }

        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data load error: \(error)")
            }
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    var context: NSManagedObjectContext { container.viewContext }

    func saveContext() throws {
        guard context.hasChanges else { return }
        try context.save()
    }
}
