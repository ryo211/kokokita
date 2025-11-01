import Foundation

/// タクソノミー（ラベル/グループ/メンバー）のソート・フィルタリングロジック
struct TaxonomySorter {

    /// 名前の空白をトリミングして空でないアイテムのみフィルタ
    /// - Parameter items: フィルタ対象のアイテムリスト
    /// - Returns: 空名でないアイテムのリスト
    static func filterEmptyNames<T: TaxonomyTag>(_ items: [T]) -> [T] {
        return items.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// 名前でローカライズされた昇順ソート
    /// - Parameter items: ソート対象のアイテムリスト
    /// - Returns: ソート済みのアイテムリスト
    static func sortByName<T: TaxonomyTag>(_ items: [T]) -> [T] {
        return items.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    /// フィルタリングとソートを一度に実行
    /// - Parameter items: 処理対象のアイテムリスト
    /// - Returns: フィルタリング＆ソート済みのアイテムリスト
    static func filterAndSort<T: TaxonomyTag>(_ items: [T]) -> [T] {
        return sortByName(filterEmptyNames(items))
    }
}
