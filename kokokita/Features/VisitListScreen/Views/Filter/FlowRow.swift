import SwiftUI

struct FlowRow: Layout {
    var spacing: CGFloat = 6
    var rowSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .greatestFiniteMagnitude
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0

        for v in subviews {
            let sz = v.sizeThatFits(.unspecified)

            // 折り返し判定は「次を置く前の spacing を含めて」行う
            if x > 0 && x + spacing + sz.width > maxW {
                x = 0
                y += rowH + rowSpacing
                rowH = 0
            }

            // 1つ目以外は spacing を足してから幅を加算
            let nextX = x + (x == 0 ? 0 : spacing) + sz.width
            x = nextX
            rowH = max(rowH, sz.height)
        }

        return CGSize(width: maxW, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxW = bounds.width
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0

        // 各行の要素を収集して、行ごとに中央配置するための情報を保持
        var rows: [[Int]] = [[]]  // 各行のsubviewインデックス
        var rowHeights: [CGFloat] = [0]  // 各行の最大高さ
        var currentRow = 0

        // まず、各行にどの要素が入るかを計算
        for (index, v) in subviews.enumerated() {
            let sz = v.sizeThatFits(.unspecified)

            // 折り返し判定
            if x > 0 && x + spacing + sz.width > maxW {
                x = 0
                currentRow += 1
                rows.append([])
                rowHeights.append(0)
            }

            rows[currentRow].append(index)
            rowHeights[currentRow] = max(rowHeights[currentRow], sz.height)

            let nextX = x + (x == 0 ? 0 : spacing) + sz.width
            x = nextX
        }

        // 次に、各行の要素を中央配置で配置
        x = 0
        y = 0
        currentRow = 0

        for (index, v) in subviews.enumerated() {
            let sz = v.sizeThatFits(.unspecified)

            // 折り返し判定
            if x > 0 && x + spacing + sz.width > maxW {
                x = 0
                y += rowHeights[currentRow] + rowSpacing
                currentRow += 1
            }

            let placeX = x + (x == 0 ? 0 : spacing)
            // 行の中央に配置するため、(行の高さ - 要素の高さ) / 2 をy座標に加算
            let centerOffset = (rowHeights[currentRow] - sz.height) / 2
            let pos = CGPoint(x: bounds.minX + placeX, y: bounds.minY + y + centerOffset)
            v.place(at: pos, proposal: .unspecified)

            x = placeX + sz.width
        }
    }
}
