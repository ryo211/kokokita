import Foundation

/// 日付操作のヘルパー関数（純粋関数）
struct DateHelper {

    /// 指定日付の終了時刻+1秒を計算（範囲検索用）
    /// - Parameter date: 対象の日付
    /// - Returns: 23:59:59の翌秒（翌日の00:00:00）
    func calculateEndExclusive(_ date: Date) -> Date {
        let calendar = Calendar.current
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date
        return calendar.date(byAdding: .second, value: 1, to: endOfDay) ?? endOfDay
    }

    /// 日付を日の開始時刻に正規化
    /// - Parameter date: 対象の日付
    /// - Returns: 00:00:00の時刻
    func startOfDay(_ date: Date) -> Date {
        return Calendar.current.startOfDay(for: date)
    }
}
