import SwiftUI

/// ページ3のビジュアル: 位置情報アイコンを、アクセント色の円と、その周りの薄い円で大きく表示する
/// 装飾なので VoiceOver からは除外する（内容は見出し・本文で伝える）
struct OnboardingLocationVisual: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.brandAccent.opacity(0.14))
                .frame(width: 168, height: 168)

            Circle()
                .fill(Color.brandAccent)
                .frame(width: 104, height: 104)
                .shadow(color: Color.brandAccent.opacity(0.35), radius: 16, x: 0, y: 8)

            Image(systemName: "location.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}
