import CoreData

final class CoreDataStack {
    static let shared = CoreDataStack()
    let container: NSPersistentContainer
    private(set) var loadError: Error?

    init(modelName: String = "Kokokita") {
        container = NSPersistentContainer(name: modelName)

        // 軽量マイグレーションを有効化
        if let desc = container.persistentStoreDescriptions.first {
            desc.shouldInferMappingModelAutomatically = true
            desc.shouldMigrateStoreAutomatically = true
        }

        container.loadPersistentStores { [weak self] storeDescription, error in
            if let error = error {
                Logger.error("Core Data load error", error: error)
                self?.loadError = error
                // UI側でエラー画面を表示するため、ここでは何もしない
            }
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    /// CoreDataが正常に読み込まれたかどうか
    var isHealthy: Bool {
        return loadError == nil
    }

    var context: NSManagedObjectContext { container.viewContext }

    func saveContext() throws {
        guard context.hasChanges else { return }
        try context.save()
    }
}
