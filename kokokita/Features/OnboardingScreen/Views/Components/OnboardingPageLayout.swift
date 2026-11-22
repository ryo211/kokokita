import SwiftUI

/// オンボーディング全体で共通のレイアウト定数
enum OnboardingLayout {
    /// 左右の余白
    static let horizontalPadding: CGFloat = 24
    /// iPad などの広い画面でも読みやすい幅に抑えるための最大幅
    static let maxContentWidth: CGFloat = 540
    /// ビジュアルとテキスト（アイブロウ）の間隔。両者の距離はこの値で調整する
    static let visualToTextSpacing: CGFloat = 32
    /// 上下に確保する余白
    static let verticalMargin: CGFloat = 24
    /// ビジュアル領域の最小の高さ（大きい文字サイズでテキストが長くなっても、これ以上は縮めずスクロールさせる）
    static let minVisualHeight: CGFloat = 160
}

/// オンボーディング各ページの共通レイアウト（フッターを除く部分）
///
/// テキストは下側に確保した領域の上端から並べ、ビジュアルは残りの領域に置く。
/// テキスト領域の高さは「自身のテキストの高さ」と `textAreaHeight` の大きい方。
/// ページ1・2のように文言の位置をそろえたいページ同士は、共通の `textAreaHeight` を渡す。
/// 画面に収まらない場合（大きい文字サイズなど）だけ縦スクロールできるようにする
struct OnboardingPageLayout<Visual: View, TextContent: View>: View {
    /// テキスト領域の最小の高さ。文言の位置をそろえたいページ同士で共通の値を渡す（不要なら 0）
    var textAreaHeight: CGFloat = 0
    /// ビジュアル領域の中での配置。動画は文言に近づけるため下寄せ（既定）、
    /// ページ3のアイコンのように領域より十分小さいものは中央に置く
    var visualAlignment: Alignment = .bottom
    /// ビジュアル。引数はビジュアルが使ってよい最大サイズ
    @ViewBuilder let visual: (CGSize) -> Visual
    /// テキスト部分（OnboardingTextBlock）
    @ViewBuilder let text: () -> TextContent

    /// 自身のテキスト部分の実際の高さ
    @State private var ownTextHeight: CGFloat = 0

    private var effectiveTextAreaHeight: CGFloat { max(ownTextHeight, textAreaHeight) }

    var body: some View {
        GeometryReader { geo in
            let contentWidth = max(
                min(geo.size.width, OnboardingLayout.maxContentWidth) - OnboardingLayout.horizontalPadding * 2,
                0
            )
            let visualHeight = max(
                geo.size.height
                    - OnboardingLayout.verticalMargin * 2
                    - OnboardingLayout.visualToTextSpacing
                    - effectiveTextAreaHeight,
                OnboardingLayout.minVisualHeight
            )

            ScrollView {
                VStack(spacing: 0) {
                    visual(CGSize(width: contentWidth, height: visualHeight))
                        .frame(width: contentWidth, height: visualHeight, alignment: visualAlignment)

                    text()
                        .frame(width: contentWidth, alignment: .leading)
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.size.height
                        } action: { height in
                            ownTextHeight = height
                        }
                        .frame(minHeight: effectiveTextAreaHeight, alignment: .top)
                        .padding(.top, OnboardingLayout.visualToTextSpacing)
                }
                .padding(.vertical, OnboardingLayout.verticalMargin)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
    }
}

/// オンボーディングのテキスト部分（アイブロウ／見出し／本文＋追加要素）
struct OnboardingTextBlock<Accessory: View>: View {
    let eyebrow: String
    let title: String
    let message: String
    /// 本文の下に置く追加要素（ページ3の匿名データ行など）
    @ViewBuilder let accessory: () -> Accessory

    /// 見出し 30pt を基準に Dynamic Type に追従させる
    @ScaledMetric(relativeTo: .title) private var titleSize: CGFloat = 30

    init(
        eyebrow: String,
        title: String,
        message: String,
        @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.message = message
        self.accessory = accessory
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(eyebrow)
                .font(.footnote.weight(.bold))
                .tracking(1)
                .foregroundStyle(Color.brandAccent)

            Text(title)
                .font(.system(size: titleSize, weight: .black))
                .foregroundStyle(Color.brandText)
                .lineSpacing(2)
                .padding(.top, 12)
                .accessibilityAddTraits(.isHeader)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.brandTextSecondary)
                .lineSpacing(6)
                .padding(.top, 16)

            // 追加要素が無いページで余計な余白が入らないようにする
            if Accessory.self != EmptyView.self {
                accessory()
                    .padding(.top, 24)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}
