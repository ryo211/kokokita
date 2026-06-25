import Foundation
import CoreData

/// 除外エリアの Core Data エンティティ（手動実装）
@objc(ExcludedLocationEntity)
public class ExcludedLocationEntity: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ExcludedLocationEntity> {
        return NSFetchRequest<ExcludedLocationEntity>(entityName: "ExcludedLocationEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var label: String?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var radiusMeters: Double
    @NSManaged public var createdAt: Date?
}

// MARK: - Entity → Domain 変換

extension ExcludedLocationEntity {
    func toDomain() -> ExcludedLocation {
        ExcludedLocation(
            id: id ?? UUID(),
            label: label,
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radiusMeters > 0 ? radiusMeters : 300,
            createdAt: createdAt ?? Date()
        )
    }
}
