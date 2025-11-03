import Foundation

extension String {
    /// ホワイトスペースをトリムした文字列
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 空白を含むかチェック
    var isBlankOrEmpty: Bool {
        trimmed.isEmpty
    }

    /// 空文字列の場合はnilを返す（バリデーション用）
    func nilIfEmpty() -> String? {
        isBlankOrEmpty ? nil : trimmed
    }

    /// 空白の場合は代替文字列を返す
    func ifBlank(_ alt: String) -> String {
        trimmed.isEmpty ? alt : self
    }

    /// 空白でなければselfを返す
    var ifNotBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
