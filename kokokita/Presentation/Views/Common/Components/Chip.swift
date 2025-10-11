//
//  Chip.swift
//  kokokita
//
//  Created by 橋本遼 on 2025/10/05.
//

import SwiftUI

struct Chip: View {
    let text: String
    let kind: ChipKind
    let showRemoveButton: Bool
    let size: ChipSize
    let onRemove: () -> Void

    var overrideSystemImage: String?
    var overrideTint: Color?

    init(
        _ text: String,
        kind: ChipKind,
        size: ChipSize = .regular,    // ← デフォルトは通常サイズ
        showRemoveButton: Bool = true,
        overrideSystemImage: String? = nil,
        overrideTint: Color? = nil,
        onRemove: @escaping () -> Void = {}
    ) {
        self.text = text
        self.kind = kind
        self.size = size
        self.showRemoveButton = showRemoveButton
        self.overrideSystemImage = overrideSystemImage
        self.overrideTint = overrideTint
        self.onRemove = onRemove
    }

    private var systemImage: String? { overrideSystemImage ?? kind.systemImage }
    private var tint: Color { overrideTint ?? kind.tint }

    // サイズに応じたフォントとパディング
    private var font: Font {
        switch size {
        case .regular: return .caption
        case .small:   return .caption2
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .regular: return UIConstants.Padding.chipVertical
        case .small:   return UIConstants.Padding.chipSmallVertical
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .regular: return UIConstants.Padding.chipHorizontal
        case .small:   return UIConstants.Padding.chipSmallHorizontal
        }
    }

    var body: some View {
        HStack(spacing: UIConstants.Spacing.small) {
            if let img = systemImage {
                Image(systemName: img)
                    .imageScale(size == .small ? .small : .medium)
            }
            Text(text).lineLimit(1)

            if showRemoveButton {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .imageScale(size == .small ? .small : .medium)
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
    case keyword      // キーワード/タイトル検索
    case period       // 期間（From〜To）
    case poiCategory  // ココカモのカテゴリ表示など
    case other        // 予備

    var systemImage: String? {
        switch self {
        case .label:       return "tag"
        case .group:       return "folder"
        case .keyword:     return "magnifyingglass"
        case .period:      return "calendar"
        case .poiCategory: return "mappin.and.ellipse"
        case .other:       return nil
        }
    }

    /// チップのトーン（前景色／背景色の元色）
    var tint: Color {
        switch self {
        case .label:       return .purple
        case .group:       return .teal
        case .keyword:     return .blue
        case .period:      return .orange
        case .poiCategory: return .green
        case .other:       return .secondary
        }
    }
}

enum ChipSize {
    case regular   // 通常サイズ（デフォルト）
    case small     // 記録一覧などの小型
}
