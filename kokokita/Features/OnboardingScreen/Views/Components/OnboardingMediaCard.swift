import SwiftUI

/// ページ1・2のビジュアル: 実際のアプリ画面を録画した素材を角丸カードとして表示する
/// - 動画があればミュートでループ再生（`isActive` の間だけ再生）
/// - Reduce Motion 有効時、または動画が無いときは静止画
/// - どちらも無ければプレースホルダー
/// 素材の縦横比は維持し、`OnboardingMedia.cropRect` の範囲だけを切り抜いて表示する
struct OnboardingMediaCard: View {
    let media: OnboardingMedia
    let isActive: Bool
    /// カードが使ってよい最大サイズ。縦横比を保ったまま、この中に収まる最大の大きさで表示する
    /// （ScrollView 内では高さの提案が無制限になるため、呼び出し側で上限を確定させて渡す）
    let maxSize: CGSize

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cornerRadius: CGFloat = 28

    private var videoURL: URL? { media.videoURL }
    private var stillImage: UIImage? { media.stillImage }

    /// 素材全体の縦横比（幅 / 高さ）。静止画の実寸を優先する（差し替え時にコード修正を不要にするため）
    private var sourceAspectRatio: CGFloat {
        if let size = stillImage?.size, size.height > 0 {
            return size.width / size.height
        }
        return media.fallbackAspectRatio
    }

    /// 切り抜いた後のカードの縦横比
    private var cardAspectRatio: CGFloat {
        let crop = media.cropRect
        guard crop.height > 0 else { return sourceAspectRatio }
        return sourceAspectRatio * crop.width / crop.height
    }

    /// maxSize に収まる、縦横比を保った表示サイズ
    private var cardSize: CGSize {
        let aspect = max(cardAspectRatio, 0.01)
        let width = min(maxSize.width, maxSize.height * aspect)
        return CGSize(width: max(width, 0), height: max(width / aspect, 0))
    }

    var body: some View {
        content
            .frame(width: cardSize.width, height: cardSize.height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.brandText.opacity(0.06), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(media.accessibilityLabel)
            .accessibilityAddTraits(.isImage)
    }

    @ViewBuilder
    private var content: some View {
        if let videoURL, !reduceMotion {
            cropped {
                LoopingVideoPlayerView(url: videoURL, isPlaying: isActive)
            }
        } else if let stillImage {
            cropped {
                Image(uiImage: stillImage)
                    .resizable()
                    .scaledToFill()
            }
        } else {
            placeholder
        }
    }

    /// 素材全体を「カード幅 / 切り抜き幅」の大きさに広げ、切り抜き範囲がカードに収まるようずらす
    private func cropped<Content: View>(@ViewBuilder _ source: () -> Content) -> some View {
        let crop = media.cropRect
        let source = source()
        return GeometryReader { geo in
            let fullWidth = geo.size.width / max(crop.width, 0.01)
            let fullHeight = geo.size.height / max(crop.height, 0.01)
            source
                .frame(width: fullWidth, height: fullHeight)
                .offset(x: -crop.minX * fullWidth, y: -crop.minY * fullHeight)
        }
        .clipped()
    }

    /// 素材が届くまでの仮表示（誤ってそのまま出荷しても違和感が出ないよう、文字は入れない）
    private var placeholder: some View {
        ZStack {
            Color.brandSurface
            Image(systemName: media.placeholderSymbol)
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(Color.brandAccent.opacity(0.35))
        }
    }
}
