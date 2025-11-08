import Foundation

// MARK: - Filter Criteria

/// フィルタ条件を表す構造体
struct FilterCriteria {
    let labelIds: [UUID]
    let groupIds: [UUID]
    let memberIds: [UUID]
    let categories: [String]
    let titleQuery: String
    let dateFrom: Date?
    let dateTo: Date?
}

// MARK: - Visit Filter

/// 訪問記録のフィルタリングロジック（純粋関数）
struct VisitFilter {

    /// フィルタ条件が有効かどうかを判定
    func hasActiveFilters(_ criteria: FilterCriteria) -> Bool {
        return !criteria.labelIds.isEmpty
            || !criteria.groupIds.isEmpty
            || !criteria.memberIds.isEmpty
            || !criteria.categories.isEmpty
            || !criteria.titleQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || criteria.dateFrom != nil
            || criteria.dateTo != nil
    }

    /// クライアントサイドフィルタリングを適用（ラベル、グループ、カテゴリ、メンバー）
    func applyClientSideFilters(_ visits: [VisitAggregate], criteria: FilterCriteria) -> [VisitAggregate] {
        var result = visits

        // ラベルフィルタ（複数）- いずれかのラベルを含む
        if !criteria.labelIds.isEmpty {
            result = result.filter { visit in
                criteria.labelIds.contains { labelId in
                    visit.details.labelIds.contains(labelId)
                }
            }
        }

        // グループフィルタ（複数）- いずれかのグループに一致
        if !criteria.groupIds.isEmpty {
            result = result.filter { visit in
                if let groupId = visit.details.groupId {
                    return criteria.groupIds.contains(groupId)
                }
                return false
            }
        }

        // カテゴリフィルタ（複数）- いずれかのカテゴリに一致
        if !criteria.categories.isEmpty {
            result = result.filter { visit in
                if let category = visit.details.facilityCategory {
                    return criteria.categories.contains(category)
                }
                return false
            }
        }

        // メンバーフィルタ（複数）- いずれかのメンバーを含む
        if !criteria.memberIds.isEmpty {
            result = result.filter { visit in
                criteria.memberIds.contains { memberId in
                    visit.details.memberIds.contains(memberId)
                }
            }
        }

        return result
    }
}
