import Foundation
import SwiftUI

// MARK: - Taxonomy Collection Extensions

extension Collection where Element == LabelTag {
    /// UUID -> 名前の辞書を作成
    var nameMap: [UUID: String] {
        Dictionary(uniqueKeysWithValues: map { ($0.id, $0.name) })
    }

    /// 空白名を除外（順序はリポジトリ側の並び順＝最後に使った順を維持する）
    var excludingBlankNames: [LabelTag] {
        filter { !$0.name.isBlankOrEmpty }
    }

    /// ラベル名 → Color のマップ（色設定ありのみ）
    var colorMap: [String: Color] {
        reduce(into: [:]) { map, label in
            if let color = LabelColorId.from(label.colorId)?.color {
                map[label.name] = color
            }
        }
    }
}

extension Collection where Element == GroupTag {
    /// UUID -> 名前の辞書を作成
    var nameMap: [UUID: String] {
        Dictionary(uniqueKeysWithValues: map { ($0.id, $0.name) })
    }

    /// 空白名を除外（順序はリポジトリ側の並び順＝最後に使った順を維持する）
    var excludingBlankNames: [GroupTag] {
        filter { !$0.name.isBlankOrEmpty }
    }
}

extension Collection where Element == MemberTag {
    /// UUID -> 名前の辞書を作成
    var nameMap: [UUID: String] {
        Dictionary(uniqueKeysWithValues: map { ($0.id, $0.name) })
    }

    /// 空白名を除外（順序はリポジトリ側の並び順＝最後に使った順を維持する）
    var excludingBlankNames: [MemberTag] {
        filter { !$0.name.isBlankOrEmpty }
    }
}
