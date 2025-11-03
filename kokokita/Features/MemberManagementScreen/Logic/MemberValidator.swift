import Foundation

/// メンバーのバリデーションロジック
struct MemberValidator {

    /// 名前をトリミングして検証
    /// - Parameter name: 検証する名前
    /// - Returns: トリミング後の名前（空の場合はnil）
    static func validateName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// メンバー名の重複チェック
    /// - Parameters:
    ///   - name: チェックする名前
    ///   - existingMembers: 既存のメンバーリスト
    /// - Returns: 重複している場合はtrue
    static func isDuplicate(_ name: String, in existingMembers: [MemberTag]) -> Bool {
        return existingMembers.contains(where: { $0.name == name })
    }

    /// 名前が空でないかチェック
    /// - Parameter name: チェックする名前
    /// - Returns: 空でない場合はtrue
    static func isNotEmpty(_ name: String) -> Bool {
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
