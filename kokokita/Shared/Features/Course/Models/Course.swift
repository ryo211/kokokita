import Foundation

// コースを表すドメインモデル
struct Course: Identifiable, Equatable {
    let id: UUID
    let courseType: CourseType
    let title: String
    let summary: String?
    let source: CourseSource
    let isUserCreated: Bool
    /// バンドルJSONのバージョン（更新検知用）
    let version: Int
    /// コースレベルのデフォルト認識半径（メートル）
    let recognitionRadiusMeters: Double
    /// 現在有効かどうか
    let isEnabled: Bool
    /// 一度でも有効化したことがあるか（遡り判定トリガー）
    let everEnabled: Bool
    let detailUrl: String?
    let coverImageUrl: String?
    let createdAt: Date
    let updatedAt: Date
    /// スポット一覧（orderIndex 昇順）
    let spots: [CourseSpot]

    /// チェックイン済みスポット数
    var checkedInCount: Int { spots.filter { $0.isCheckedIn }.count }

    /// 全スポット数
    var totalSpotCount: Int { spots.count }

    /// 達成率（0.0〜1.0）
    var completionRate: Double {
        guard totalSpotCount > 0 else { return 0 }
        return Double(checkedInCount) / Double(totalSpotCount)
    }

    /// 全スポット制覇済みか
    var isCompleted: Bool { checkedInCount == totalSpotCount && totalSpotCount > 0 }
}
