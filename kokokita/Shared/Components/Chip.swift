import SwiftUI

struct Chip: View {
    let text: String
    let kind: ChipKind
    let showRemoveButton: Bool
    let size: ChipSize
    let onRemove: () -> Void

    var overrideSystemImage: String?
    var overrideTint: Color?
    var colorDot: Color?

    init(
        _ text: String,
        kind: ChipKind,
        size: ChipSize = .regular,    // ← デフォルトは通常サイズ
        showRemoveButton: Bool = true,
        overrideSystemImage: String? = nil,
        overrideTint: Color? = nil,
        colorDot: Color? = nil,
        onRemove: @escaping () -> Void = {}
    ) {
        self.text = text
        self.kind = kind
        self.size = size
        self.showRemoveButton = showRemoveButton
        self.overrideSystemImage = overrideSystemImage
        self.overrideTint = overrideTint
        self.colorDot = colorDot
        self.onRemove = onRemove
    }

    private var systemImage: String? { overrideSystemImage ?? kind.systemImage }
    private var tint: Color { overrideTint ?? kind.tint }

    // サイズに応じたフォントとパディング
    private var font: Font {
        switch size {
        case .regular: return .caption.bold()
        case .small:   return .caption2.bold()
        case .xsmall:  return .caption2.bold()
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .regular: return UIConstants.Padding.chipVertical
        case .small:   return UIConstants.Padding.chipSmallVertical
        case .xsmall:  return 2
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .regular: return UIConstants.Padding.chipHorizontal
        case .small:   return UIConstants.Padding.chipSmallHorizontal
        case .xsmall:  return 6
        }
    }

    private var iconScale: Image.Scale {
        switch size {
        case .regular: return .medium
        case .small:   return .medium
        case .xsmall:  return .small
        }
    }

    /// アイコンの色（ラベル色が設定されていればその色、なければ tint）
    private var iconColor: Color {
        colorDot ?? tint
    }

    // 表示用のテキスト（10文字制限）
    private var displayText: String {
        if text.count > 10 {
            return String(text.prefix(10)) + "..."
        }
        return text
    }

    var body: some View {
        HStack(spacing: size == .xsmall ? 2 : UIConstants.Spacing.small) {
            if let img = systemImage {
                Image(systemName: img)
                    .imageScale(iconScale)
                    .foregroundStyle(iconColor)
            }
            Text(displayText)
                .lineLimit(1)

            if showRemoveButton {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .imageScale(iconScale)
                }
                .buttonStyle(.plain)
            }
        }
        .font(font)
        .padding(.vertical, verticalPadding)
        .padding(.horizontal, horizontalPadding)
        .background(tint.opacity(UIConstants.Alpha.chipBackground), in: Capsule())
        .foregroundStyle(tint)
    }
}



enum ChipKind {
    case label        // ラベル
    case group        // グループ
    case member       // メンバー
    case category     // カテゴリフィルタ
    case keyword      // キーワード/タイトル検索
    case period       // 期間（From〜To）
    case poiCategory  // ココカモのカテゴリ表示など
    case other        // 予備

    var systemImage: String? {
        switch self {
        case .label:       return "tag"
        case .group:       return "folder"
        case .member:      return "person"
        case .category:    return "building.2"
        case .keyword:     return "magnifyingglass"
        case .period:      return "calendar"
        case .poiCategory: return "mappin.and.ellipse"
        case .other:       return nil
        }
    }

    /// チップの統一カラー
    static let defaultTint = Color(.systemGray)

    /// チップのトーン（前景色／背景色の元色）
    var tint: Color {
        Self.defaultTint
    }
}

enum ChipSize {
    case regular   // 通常サイズ（デフォルト）
    case small     // 記録一覧などの小型
    case xsmall    // より小型（タクソノミー詳細画面など）
}
