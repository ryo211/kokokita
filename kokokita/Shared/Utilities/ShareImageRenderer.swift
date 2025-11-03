import SwiftUI
import UIKit

/// 共有用画像のレンダリングユーティリティ
@MainActor
enum ShareImageRenderer {
    /// 幅だけ与えて"高さは中身に合わせる"画像化
    static func renderWidth<V: View>(_ view: V, width: CGFloat, scale: CGFloat = 3) -> UIImage? {
        if #available(iOS 16.0, *) {
            // 高さは中身に合わせるため fixedSize を併用
            let content =
                view
                    .frame(width: width)
                    .fixedSize(horizontal: false, vertical: true) // ← ココ重要
                    .transaction { $0.disablesAnimations = true } // 画像化時にアニメ無効
                    .environment(\.colorScheme, .light)           // 任意：共有はライト固定

            let renderer = ImageRenderer(content: content)
            renderer.scale = scale
            renderer.isOpaque = false
            return renderer.uiImage
        } else {
            // iOS 15 フォールバック（UIHostingController）
            let hosting = UIHostingController(
                rootView:
                    view
                        .frame(width: width)
                        .fixedSize(horizontal: false, vertical: true)
            )
            hosting.view.backgroundColor = .clear
            hosting.view.setNeedsLayout()
            hosting.view.layoutIfNeeded()

            // AutoLayout で必要な実サイズを計測
            let target = hosting.sizeThatFits(
                in: CGSize(width: width, height: .greatestFiniteMagnitude)
            )
            hosting.view.bounds = CGRect(origin: .zero, size: target)

            let renderer = UIGraphicsImageRenderer(
                size: CGSize(width: target.width * scale, height: target.height * scale)
            )
            return renderer.image { ctx in
                ctx.cgContext.scaleBy(x: scale, y: scale)
                hosting.view.layer.render(in: ctx.cgContext)
            }
        }
    }
}
