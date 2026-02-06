import SwiftUI

/// ラベルの色選択グリッド（2行×5列 + 先頭に「色なし」）
struct LabelColorPicker: View {
    let selectedColorId: String?
    let onSelect: (String?) -> Void

    /// 2行×5列+1のグリッド配置
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            // 「色なし」ボタン
            noColorSwatch

            // プリセット10色
            ForEach(LabelColorId.allCases) { colorId in
                colorSwatch(colorId)
            }
        }
    }

    /// 「色なし」スウォッチ
    private var noColorSwatch: some View {
        let isSelected = selectedColorId == nil
        return Button {
            onSelect(nil)
        } label: {
            ZStack {
                Circle()
                    .fill(Color(.systemGray4))
                    .frame(width: 32, height: 32)

                if isSelected {
                    Circle()
                        .strokeBorder(Color.primary, lineWidth: 2)
                        .frame(width: 38, height: 38)
                }

                Image(systemName: isSelected ? "checkmark" : "xmark")
                    .font(.caption2.bold())
                    .foregroundStyle(isSelected ? Color.primary : .secondary)
            }
            .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L.LabelColor.noColor)
    }

    /// 色スウォッチ
    private func colorSwatch(_ colorId: LabelColorId) -> some View {
        let isSelected = selectedColorId == colorId.rawValue
        return Button {
            onSelect(colorId.rawValue)
        } label: {
            ZStack {
                Circle()
                    .fill(colorId.color)
                    .frame(width: 32, height: 32)

                if isSelected {
                    Circle()
                        .strokeBorder(Color.primary, lineWidth: 2)
                        .frame(width: 38, height: 38)

                    Image(systemName: "checkmark")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(colorId.displayName)
    }
}
