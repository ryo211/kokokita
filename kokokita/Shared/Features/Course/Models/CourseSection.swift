import Foundation

// コース内のセクション（スポットのグループ）を表すドメインモデル
// sectionId == nil の場合は「セクションなし」の仮想セクション（従来の spots 直下フォーマット用）
struct CourseSection: Identifiable, Equatable {
    let id: UUID
    /// JSON 識別子。nil の場合は後方互換用の仮想セクション
    let sectionId: String?
    let name: String
    let sectionDescription: String?
    /// コース内での表示順（0始まり）
    let orderIndex: Int
    let coverImageUrl: String?
    /// セクション内スポット一覧（orderIndex 昇順）
    let spots: [CourseSpot]

    /// セクション名が存在するかどうか（UI でのヘッダー表示判定に使用）
    var hasName: Bool { sectionId != nil }
}
