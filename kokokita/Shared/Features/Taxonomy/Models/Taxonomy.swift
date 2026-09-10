import Foundation

/// name プロパティを持つタクソノミー型共通のプロトコル（未使用タグの名前順フォールバック等で使用）
protocol TaxonomyNamed {
    var name: String { get }
}

/// ラベルタグ
struct LabelTag: Identifiable, Codable, Equatable, Hashable, TaxonomyNamed {
    let id: UUID
    var name: String
    var colorId: String?
}

/// グループタグ
struct GroupTag: Identifiable, Codable, Equatable, Hashable, TaxonomyNamed {
    let id: UUID
    var name: String
}

/// メンバータグ
struct MemberTag: Identifiable, Codable, Equatable, Hashable, TaxonomyNamed {
    let id: UUID
    var name: String
}
