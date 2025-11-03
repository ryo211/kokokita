import Foundation

/// 日付グループを表す構造体
struct DateGroup: Identifiable {
    let id: String
    let date: Date
    let items: [VisitAggregate]
}

/// 訪問記録のグルーピングロジック（純粋関数）
struct VisitGrouper {

    /// 訪問記録を日付ごとにグループ化
    /// - Parameters:
    ///   - visits: グループ化対象の訪問記録配列
    ///   - ascending: true = 昇順（古い順）、false = 降順（新しい順）
    /// - Returns: 日付グループの配列
    func groupByDate(_ visits: [VisitAggregate], ascending: Bool) -> [DateGroup] {
        let calendar = Calendar.current

        // 日付ごとにグループ化
        let grouped = Dictionary(grouping: visits) { item in
            calendar.startOfDay(for: item.visit.timestampUTC)
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // DateGroup配列に変換
        return grouped.map { (date, items) in
            DateGroup(
                id: dateFormatter.string(from: date),
                date: date,
                items: items.sorted { a, b in
                    ascending ? (a.visit.timestampUTC < b.visit.timestampUTC)
                              : (a.visit.timestampUTC > b.visit.timestampUTC)
                }
            )
        }.sorted { a, b in
            ascending ? (a.date < b.date) : (a.date > b.date)
        }
    }
}
