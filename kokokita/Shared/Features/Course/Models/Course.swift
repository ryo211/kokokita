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
    /// 遡り判定実施済みかどうか（初回インポート後に自動実行）
    let everEnabled: Bool
    /// コース一覧への表示・達成判定の有効/無効
    let isEnabled: Bool
    /// 旧仕様との互換用に保持しているフラグ（現行の遡り判定では未使用）
    let allowRetroactive: Bool
    let detailUrl: String?
    let coverImageUrl: String?
    /// カバー画像のクレジット表記（Wikimedia Commons 等の帰属表示用）
    let imageCredit: String?
    /// 端末内カバー画像パス（ユーザー作成コース用）
    let localCoverImagePath: String?
    let createdAt: Date
    let updatedAt: Date
    /// コースに付与されたカテゴリ（複数可）
    let categories: [CourseCategory]
    /// セクション一覧（orderIndex 昇順）
    let sections: [CourseSection]

    /// 全スポット一覧（セクションをフラット展開）。後方互換・認識処理用
    var spots: [CourseSpot] { sections.flatMap(\.spots) }

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
