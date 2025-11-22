import Foundation

// MARK: - DateFormatter Extensions

extension DateFormatter {
    /// JST表示用のフォーマッタ（保存はUTC、表示はJST）
    static let jst: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = AppConfig.dateDisplayFormat
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return f
    }()
}

// MARK: - Date Formatters

enum AppDateFormatters {
    /// 例: 2025/10/04 (土) 21:30 (日本語) / Oct 4, 2025 (Sat) 9:30 PM (英語)
    static var visitDateTime: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale.current
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .current

        // ロケールに応じて日付フォーマットを切り替え
        if Locale.current.language.languageCode?.identifier == "ja" {
            f.dateFormat = "yyyy/MM/dd (E) HH:mm"
        } else {
            f.dateFormat = "MMM d, yyyy (E) h:mm a"
        }
        return f
    }

    /// リスト画面の日付ヘッダー用（例: 2025年10月4日(土) / October 4, 2025 (Sat)）
    static var listDateHeader: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale.current
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .current

        // ロケールに応じて日付フォーマットを切り替え
        if Locale.current.language.languageCode?.identifier == "ja" {
            f.dateFormat = "yyyy年M月d日(E)"
        } else {
            f.dateFormat = "MMMM d, yyyy (E)"
        }
        return f
    }

    /// フィルター表示用の短い日付（例: 2025/10/04 / Oct 4, 2025）
    static var filterDate: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale.current
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .current

        // ロケールに応じて日付フォーマットを切り替え
        if Locale.current.language.languageCode?.identifier == "ja" {
            f.dateFormat = "yyyy/MM/dd"
        } else {
            f.dateFormat = "MMM d, yyyy"
        }
        return f
    }
}

// MARK: - Date Extensions

extension Date {
    /// ココキタの統一日時表示
    var kokokitaVisitString: String {
        AppDateFormatters.visitDateTime.string(from: self)
    }
}
