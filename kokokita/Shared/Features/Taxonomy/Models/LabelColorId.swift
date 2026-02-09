import SwiftUI

/// ラベルに設定可能なプリセット色の識別子
enum LabelColorId: String, CaseIterable, Codable, Identifiable {
    case red, orange, amber, green, teal, cyan, blue, indigo, purple, pink, brown

    var id: String { rawValue }

    /// システムカラーへのマッピング（ダークモード自動対応）
    var color: Color {
        switch self {
        case .red:    return Color(.systemRed)
        case .orange: return Color(.systemOrange)
        case .amber:  return Color(.systemYellow)
        case .green:  return Color(.systemGreen)
        case .teal:   return Color(.systemTeal)
        case .cyan:   return Color(.systemCyan)
        case .blue:   return Color(.systemBlue)
        case .indigo: return Color(.systemIndigo)
        case .purple: return Color(.systemPurple)
        case .pink:   return Color(.systemPink)
        case .brown:  return Color(.systemBrown)
        }
    }

    /// ローカライズされた表示名
    var displayName: String {
        switch self {
        case .red:    return L.LabelColor.red
        case .orange: return L.LabelColor.orange
        case .amber:  return L.LabelColor.amber
        case .green:  return L.LabelColor.green
        case .teal:   return L.LabelColor.teal
        case .cyan:   return L.LabelColor.cyan
        case .blue:   return L.LabelColor.blue
        case .indigo: return L.LabelColor.indigo
        case .purple: return L.LabelColor.purple
        case .pink:   return L.LabelColor.pink
        case .brown:  return L.LabelColor.brown
        }
    }

    /// rawValue 文字列から LabelColorId を取得（nil 安全）
    static func from(_ rawValue: String?) -> LabelColorId? {
        guard let rawValue else { return nil }
        return LabelColorId(rawValue: rawValue)
    }
}
