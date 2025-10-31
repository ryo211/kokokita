//
//  FlowRow.swift
//  kokokita
//
//  Created by 橋本遼 on 2025/09/30.
//

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

        for v in subviews {
            let sz = v.sizeThatFits(.unspecified)

            // 折り返し判定は「置く前の spacing を含めて」
            if x > 0 && x + spacing + sz.width > maxW {
                x = 0
                y += rowH + rowSpacing
                rowH = 0
            }

            // 置くときも、1つ目以外は spacing を“置く前に”反映
            let placeX = x + (x == 0 ? 0 : spacing)
            let pos = CGPoint(x: bounds.minX + placeX, y: bounds.minY + y)
            v.place(at: pos, proposal: .unspecified)

            // 次の開始位置を更新
            x = placeX + sz.width
            rowH = max(rowH, sz.height)
        }
    }
}
