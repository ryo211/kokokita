//
//  Taxonomy.swift
//  kokokita
//
//  Created by 橋本遼 on 2025/09/20.
//

import Foundation

/// ラベルタグ
struct LabelTag: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
}

/// グループタグ
struct GroupTag: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
}

/// メンバータグ
struct MemberTag: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
}
