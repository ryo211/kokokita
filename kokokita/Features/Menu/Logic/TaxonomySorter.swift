import Foundation

/// タクソノミー（ラベル/グループ/メンバー）のソート・フィルタリングロジック
struct TaxonomySorter {

    // MARK: - Label

    /// ラベルの空名フィルタ
    static func filterEmptyLabels(_ items: [LabelTag]) -> [LabelTag] {
        return items.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// ラベルのソート
    static func sortLabels(_ items: [LabelTag]) -> [LabelTag] {
        return items.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    /// ラベルのフィルタリング＆ソート
    static func filterAndSort(_ items: [LabelTag]) -> [LabelTag] {
        return sortLabels(filterEmptyLabels(items))
    }

    // MARK: - Group

    /// グループの空名フィルタ
    static func filterEmptyGroups(_ items: [GroupTag]) -> [GroupTag] {
        return items.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// グループのソート
    static func sortGroups(_ items: [GroupTag]) -> [GroupTag] {
        return items.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    /// グループのフィルタリング＆ソート
    static func filterAndSort(_ items: [GroupTag]) -> [GroupTag] {
        return sortGroups(filterEmptyGroups(items))
    }

    // MARK: - Member

    /// メンバーの空名フィルタ
    static func filterEmptyMembers(_ items: [MemberTag]) -> [MemberTag] {
        return items.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// メンバーのソート
    static func sortMembers(_ items: [MemberTag]) -> [MemberTag] {
        return items.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    /// メンバーのフィルタリング＆ソート
    static func filterAndSort(_ items: [MemberTag]) -> [MemberTag] {
        return sortMembers(filterEmptyMembers(items))
    }
}
