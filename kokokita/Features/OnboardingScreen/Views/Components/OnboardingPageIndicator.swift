import SwiftUI

/// オンボーディングのページインジケーター
/// 現在のページは横長（22×8）のアクセント色、それ以外は 8×8 の非アクティブ色
/// VoiceOver では「3ページ中1ページ目」と読み上げ、上下スワイプでページを切り替えられる
struct OnboardingPageIndicator: View {
    @Binding var currentPage: OnboardingPage

    var body: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingPage.allCases, id: \.self) { page in
                let isCurrent = page == currentPage
                Capsule()
                    .fill(isCurrent ? Color.brandAccent : Color.brandInactive)
                    .frame(width: isCurrent ? 22 : 8, height: 8)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: currentPage)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            L.Onboarding.pageIndicator(current: currentPage.rawValue + 1, total: OnboardingPage.allCases.count)
        )
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                if let next = OnboardingPage(rawValue: currentPage.rawValue + 1) { currentPage = next }
            case .decrement:
                if let previous = OnboardingPage(rawValue: currentPage.rawValue - 1) { currentPage = previous }
            @unknown default:
                break
            }
        }
    }
}
