import Foundation
import SwiftUI

// MARK: - Taxonomy Collection Extensions

extension Collection where Element == LabelTag {
    /// UUID -> 名前の辞書を作成
    var nameMap: [UUID: String] {
        Dictionary(uniqueKeysWithValues: map { ($0.id, $0.name) })
    }

    /// 名前でソート（空白除外済み）
    var sortedByName: [LabelTag] {
        filter { !$0.name.isBlankOrEmpty }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
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

    /// 名前でソート（空白除外済み）
    var sortedByName: [GroupTag] {
        filter { !$0.name.isBlankOrEmpty }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
}

extension Collection where Element == MemberTag {
    /// UUID -> 名前の辞書を作成
    var nameMap: [UUID: String] {
        Dictionary(uniqueKeysWithValues: map { ($0.id, $0.name) })
    }

    /// 名前でソート（空白除外済み）
    var sortedByName: [MemberTag] {
        filter { !$0.name.isBlankOrEmpty }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
}
