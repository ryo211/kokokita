import Foundation
import CoreData

/// 自動記録候補のCore Dataエンティティ（手動実装）
@objc(VisitCandidateEntity)
public class VisitCandidateEntity: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<VisitCandidateEntity> {
        return NSFetchRequest<VisitCandidateEntity>(entityName: "VisitCandidateEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var arrivalDate: Date?
    @NSManaged public var departureDate: Date?
    @NSManaged public var horizontalAccuracy: Double
    @NSManaged public var placeName: String?
    @NSManaged public var status: String?
    @NSManaged public var detectedAt: Date?
}
