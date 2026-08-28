import SwiftUI

/// アンカー（ボタン等）の直上または直下にコーチマーク吹き出しを表示する自前実装オーバーレイ
/// TipKitのpopoverTipはカスタムタブバー内で位置計算がずれることがあったため、
/// フレームを直接測定して確実な位置に表示する
struct CoachmarkOverlay: View {
    enum Placement {
        case above
        case below
    }

    let title: String
    let message: String
    /// アンカーのグローバル座標系でのフレーム
    let anchorFrame: CGRect
    /// このオーバーレイを描画するコンテナのグローバル座標系でのフレーム
    let containerFrame: CGRect
    var placement: Placement = .above
    /// 閉じる（×）ボタンのタップ時に呼ぶ。nilの場合は閉じるボタンを表示しない
    var onDismiss: (() -> Void)? = nil

    /// 吹き出しの幅は曖昧さを排除するため固定値にする（.frame(maxWidth:)は内容が短くても
    /// 領域いっぱいに広がることがあり、その場合バブル全体の中心がアンカーとズレていた）
    private let bubbleWidth: CGFloat = 220
    @State private var bubbleHeight: CGFloat = 0

    private var anchorCenterX: CGFloat {
        anchorFrame.midX - containerFrame.minX
    }

    private var anchorEdgeY: CGFloat {
        (placement == .above ? anchorFrame.minY : anchorFrame.maxY) - containerFrame.minY
    }

    /// 吹き出し全体（中央揃え）の水平位置。コンテナ端から十分な余白を保ってクランプする
    /// （閉じるボタンが右上に少しはみ出す分も見込んで、片端8ptより広めのマージンを取る）
    private var clampedCenterX: CGFloat {
        let halfWidth = bubbleWidth / 2
        let edgeMargin: CGFloat = 20
        let minX = halfWidth + edgeMargin
        let maxX = max(containerFrame.width - halfWidth - edgeMargin, minX)
        return min(max(anchorCenterX, minX), maxX)
    }

    /// カード背景: 単色のアクセントカラーによるフラットなデザイン
    /// （マテリアル+グラデーションの重ね掛けは中途半端な印象になったため、はっきりした単色に変更）
    private var bubbleBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.accentColor)
            .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                if placement == .below {
                    CoachmarkTriangle(pointingDown: false)
                        .fill(Color.accentColor)
                        .frame(width: 16, height: 8)
                        // 吹き出し本体は画面端でクランプされるため、矢印はバブル基準ではなく
                        // 実際のアンカー中心へオフセットして向きを合わせる
                        .offset(x: anchorCenterX - clampedCenterX)
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    // 右上に重ねる閉じるボタン分のスペースを確保
                    if onDismiss != nil {
                        Spacer(minLength: 14)
                    }
                }
                .frame(width: bubbleWidth, alignment: .leading)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(bubbleBackground)

                if placement == .above {
                    CoachmarkTriangle(pointingDown: true)
                        .fill(Color.accentColor)
                        .frame(width: 16, height: 8)
                        .offset(x: anchorCenterX - clampedCenterX)
                }
            }
            .allowsHitTesting(false)

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.7))
                }
                // カード内側の右上に収める（placement == .below の場合は矢印の分だけ下にずらす）
                .offset(x: -8, y: placement == .below ? 16 : 8)
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { bubbleHeight = geo.size.height }
                    .onChange(of: geo.size.height) { _, newHeight in bubbleHeight = newHeight }
            }
        )
        // サイズ計測前（1フレーム目）は誤った位置に一瞬表示されるのを防ぐため非表示にする
        .opacity(bubbleHeight == 0 ? 0 : 1)
        .position(
            x: clampedCenterX,
            y: placement == .above
                ? anchorEdgeY - bubbleHeight / 2 - 6
                : anchorEdgeY + bubbleHeight / 2 + 6
        )
        .animation(.easeOut(duration: 0.2), value: bubbleHeight)
    }
}

/// 吹き出しの矢印（三角形）
private struct CoachmarkTriangle: Shape {
    /// true: 下向き（吹き出しがアンカーの上にある場合）、false: 上向き（吹き出しがアンカーの下にある場合）
    let pointingDown: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if pointingDown {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        }
        path.closeSubpath()
        return path
    }
}

extension View {
    /// このビュー（ボタン等）のフレームを継続的に報告する
    /// CoachmarkOverlay のアンカー位置計算に使う
    ///
    /// - Important: `.global`はNavigationStack等のホスティング階層によっては
    ///   実際のウィンドウ座標と異なる値を返すことがあるため使わない。
    ///   必ずアンカーとコンテナの共通の祖先に`.coordinateSpace(name:)`を設定し、
    ///   同じ名前付き座標空間を指定すること
    func reportFrame(in space: CoordinateSpace, _ onChange: @escaping (CGRect) -> Void) -> some View {
        background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { onChange(geo.frame(in: space)) }
                    .onChange(of: geo.frame(in: space)) { _, newFrame in onChange(newFrame) }
            }
        )
    }
}
