import Foundation

/// 文字列バリデーションのユーティリティ（純粋関数）
struct StringValidator {

    /// 空文字や空白のみの文字列をnilに変換
    /// - Parameter string: 対象の文字列
    /// - Returns: 有効な文字列またはnil
    func nilIfBlank(_ string: String) -> String? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// 文字列が空白のみかどうかを判定
    /// - Parameter string: 対象の文字列
    /// - Returns: 空白のみの場合true
    func isBlank(_ string: String) -> Bool {
        return string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - String Extension

extension String {
    /// 空文字や空白のみの場合はnilを返す
    var nilIfBlank: String? {
        return StringValidator().nilIfBlank(self)
    }
}
