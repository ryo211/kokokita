//
//  DateExtensions.swift
//  kokokita
//
//  Created by Claude on 2025/10/11.
//

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
    /// 例: 2025/10/04 (土) 21:30
    static let visitDateTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .current
        f.dateFormat = "yyyy/MM/dd (E) HH:mm"
        return f
    }()
}

// MARK: - Date Extensions

extension Date {
    /// ココキタの統一日時表示
    var kokokitaVisitString: String {
        AppDateFormatters.visitDateTime.string(from: self)
    }
}
