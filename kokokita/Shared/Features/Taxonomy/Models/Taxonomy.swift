import Foundation

/// ラベルタグ
struct LabelTag: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var colorId: String?
}

/// グループタグ
struct GroupTag: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
}

/// メンバータグ
struct MemberTag: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
}
