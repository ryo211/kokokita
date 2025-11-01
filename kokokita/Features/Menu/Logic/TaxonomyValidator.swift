import Foundation

/// タクソノミー（ラベル/グループ/メンバー）のバリデーションロジック
struct TaxonomyValidator {

    /// 名前をトリミングして検証
    /// - Parameter name: 検証する名前
    /// - Returns: トリミング後の名前（空の場合はnil）
    static func validateName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// 重複チェック
    /// - Parameters:
    ///   - name: チェックする名前
    ///   - existingItems: 既存のアイテムリスト
    /// - Returns: 重複している場合はtrue
    static func isDuplicate<T: TaxonomyTag>(_ name: String, in existingItems: [T]) -> Bool {
        return existingItems.contains(where: { $0.name == name })
    }

    /// 名前が空でないかチェック
    /// - Parameter name: チェックする名前
    /// - Returns: 空でない場合はtrue
    static func isNotEmpty(_ name: String) -> Bool {
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// TaxonomyTag プロトコル（共通インターフェース）
protocol TaxonomyTag: Identifiable where ID == UUID {
    var id: UUID { get }
    var name: String { get }
}

// LabelTag, GroupTag, MemberTag を TaxonomyTag に準拠させる
extension LabelTag: TaxonomyTag {}
extension GroupTag: TaxonomyTag {}
extension MemberTag: TaxonomyTag {}
