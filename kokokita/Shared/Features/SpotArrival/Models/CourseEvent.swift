import Foundation

/// コース・スポットに対する「関心度」イベント（閲覧・お気に入り追加等）。
/// 到達が少ない初期の人気指標として使う。doc/server-feature-design.md フェーズ1「収集するデータ」参照
enum CourseEventType: String {
    case view
    case favoriteAdd = "favorite_add"
    /// スポット単位のお気に入り追加（courseIdに加えてspotIdも持つ）
    case spotFavoriteAdd = "spot_favorite_add"
}

struct CourseEvent {
    let id: UUID
    let courseId: UUID
    /// スポット単位のイベント（.spotFavoriteAdd）の場合のみ値を持つ。コース単位のイベントはnil
    let spotId: UUID?
    let type: CourseEventType
    /// イベント発生日（日単位に丸めた値。同じコース（・スポット）・同じ種別は1日1回までしか記録しない）
    let eventDay: Date
    let isSent: Bool
}

extension CourseEvent {
    /// (courseId, spotId, type, eventDay) から決定論的なidを導出する。
    /// 起動時フラッシュが競合して同じイベントを2回送信しても、サーバー側のon conflictで
    /// 重複挿入されないようにするための冪等キー（SpotArrival.makeIdと同じ考え方）
    static func makeId(courseId: UUID, spotId: UUID?, type: CourseEventType, eventDay: Date) -> UUID {
        let dayString = ISO8601DateFormatter.courseEventDayFormatter.string(from: eventDay)
        let spotComponent = spotId?.uuidString ?? "none"
        return CourseJSONParser.uuidFromString("\(courseId.uuidString)-\(spotComponent)-\(type.rawValue)-\(dayString)")
    }
}

private extension ISO8601DateFormatter {
    static let courseEventDayFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()
}
