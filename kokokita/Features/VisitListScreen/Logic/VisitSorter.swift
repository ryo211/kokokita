import Foundation

/// 訪問記録のソートロジック（純粋関数）
struct VisitSorter {

    /// 訪問記録を日付でソート
    /// - Parameters:
    ///   - visits: ソート対象の訪問記録配列
    ///   - ascending: true = 昇順（古い順）、false = 降順（新しい順）
    /// - Returns: ソート済みの訪問記録配列
    func sort(_ visits: [VisitAggregate], ascending: Bool) -> [VisitAggregate] {
        return visits.sorted { a, b in
            let ta = a.visit.timestampUTC
            let tb = b.visit.timestampUTC
            return ascending ? (ta < tb) : (ta > tb)
        }
    }
}
