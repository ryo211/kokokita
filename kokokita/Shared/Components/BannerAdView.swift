import SwiftUI
import GoogleMobileAds

/// 非パーソナライズ広告リクエストを作成
private func makeNonPersonalizedRequest() -> Request {
    let request = Request()
    let extras = Extras()
    extras.additionalParameters = ["npa": "1"]  // Non-Personalized Ads
    request.register(extras)
    return request
}

/// SwiftUI から使うアダプティブ・バナー（横幅に追従）
struct BannerAdView: View {
    let adUnitID: String
    @State private var height: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            BannerUIViewRepresentable(
                adUnitID: adUnitID,
                width: geo.size.width,
                height: $height
            )
            .frame(width: geo.size.width, height: height)
        }
        .frame(height: height)
    }
}

private struct BannerUIViewRepresentable: UIViewRepresentable {
    let adUnitID: String
    let width: CGFloat
    @Binding var height: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView()
        banner.adUnitID = adUnitID
        banner.rootViewController = context.coordinator.rootViewController()
        banner.delegate = context.coordinator

        let widthPt = max(width, 320)
        // ⬇️ ここを修正：AdSize.adSizeFor → adSizeFor（トップレベル関数）
        banner.adSize = adSizeFor(cgSize: CGSize(width: widthPt, height: 50))

        banner.load(makeNonPersonalizedRequest())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        let widthPt = max(width, 320)
        let newSize = adSizeFor(cgSize: CGSize(width: widthPt, height: 50)) // ⬅️ 同様に修正
        if banner.adSize.size.width != newSize.size.width {
            banner.adSize = newSize
            banner.load(makeNonPersonalizedRequest())
        }
    }


    final class Coordinator: NSObject, BannerViewDelegate {
        private let parent: BannerUIViewRepresentable
        init(_ parent: BannerUIViewRepresentable) { self.parent = parent }

        func rootViewController() -> UIViewController? {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = scene.windows.first(where: { $0.isKeyWindow }) else { return nil }
            return window.rootViewController
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            parent.height = bannerView.bounds.height
            #if DEBUG
            print("[AdMob] Banner loaded: \(bannerView.adSize.size)")
            #endif
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            #if DEBUG
            print("[AdMob] Banner failed: \(error.localizedDescription)")
            #endif
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                bannerView.load(makeNonPersonalizedRequest())
            }
        }
    }
}
