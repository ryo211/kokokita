import Foundation

// MARK: - Filter Criteria

/// フィルタ条件を表す構造体
struct FilterCriteria {
    let labelId: UUID?
    let groupId: UUID?
    let memberId: UUID?
    let category: String?
    let titleQuery: String
    let dateFrom: Date?
    let dateTo: Date?
}

// MARK: - Visit Filter

/// 訪問記録のフィルタリングロジック（純粋関数）
struct VisitFilter {

    /// フィルタ条件が有効かどうかを判定
    func hasActiveFilters(_ criteria: FilterCriteria) -> Bool {
        return criteria.labelId != nil
            || criteria.groupId != nil
            || criteria.memberId != nil
            || criteria.category != nil
            || !criteria.titleQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || criteria.dateFrom != nil
            || criteria.dateTo != nil
    }

    /// クライアントサイドフィルタリングを適用（カテゴリ、メンバー）
    func applyClientSideFilters(_ visits: [VisitAggregate], criteria: FilterCriteria) -> [VisitAggregate] {
        var result = visits

        // カテゴリフィルタ
        if let catFilter = criteria.category {
            result = result.filter { $0.details.facilityCategory == catFilter }
        }

        // メンバーフィルタ
        if let memberFilter = criteria.memberId {
            result = result.filter { $0.details.memberIds.contains(memberFilter) }
        }

        return result
    }
}
