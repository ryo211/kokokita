//
//  CollectionExtensions.swift
//  kokokita
//
//  Created by Claude on 2025/10/11.
//

import Foundation

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
