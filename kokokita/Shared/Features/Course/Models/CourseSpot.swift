import Foundation

// コース内の個別スポットを表すドメインモデル
struct CourseSpot: Identifiable, Equatable {
    let id: UUID
    /// コース内でのスポット識別子（課金保護用、変更禁止）
    let spotId: String
    let name: String
    /// 住所（JSON から提供、任意）
    let address: String?
    let latitude: Double
    let longitude: Double
    let spotDescription: String?
    /// コース内での表示順（0始まり）
    let orderIndex: Int
    /// スポット固有の認識半径（nil の場合はコースのデフォルト値を使用）
    let recognitionRadiusMeters: Double?
    /// チェックイン済みかどうか（visitIds が空でなければ true）
    var isCheckedIn: Bool { !visitIds.isEmpty }
    /// 地図に表示できる有効な座標かどうか
    var hasValidCoordinate: Bool {
        latitude >= -90 && latitude <= 90 &&
        longitude >= -180 && longitude <= 180 &&
        !(latitude == 0 && longitude == 0)
    }
    /// 初回チェックイン日時（遡り判定の場合は過去の訪問日時）
    let firstCheckedInAt: Date?
    /// このスポットにリンクされた訪問記録の ID 一覧（VisitEntity.id）
    let visitIds: [UUID]
}
