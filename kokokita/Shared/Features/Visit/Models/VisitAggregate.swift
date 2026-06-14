import Foundation

/// 訪問記録の集約（不変データ + 可変データ）
struct VisitAggregate: Identifiable, Codable, Equatable {
    let id: UUID
    let visit: Visit
    var details: VisitDetails
    /// ゴミ箱に移動された日時（nil の場合はゴミ箱外）
    var deletedAt: Date?
}
