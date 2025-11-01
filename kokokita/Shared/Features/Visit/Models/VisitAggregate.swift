import Foundation

/// 訪問記録の集約（不変データ + 可変データ）
struct VisitAggregate: Identifiable, Codable, Equatable {
    let id: UUID
    let visit: Visit
    var details: VisitDetails
}
