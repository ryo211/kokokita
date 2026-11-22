import SwiftUI

/// オンボーディングのメインボタン（高さ56のカプセル型、アクセント色）
/// オンボーディング内ではシステムブルーを使わず BrandAccent に統一する
struct OnboardingPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            // 大きい文字サイズで文字が折り返しても切れないよう、高さは最小値として指定する
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Capsule().fill(Color.brandAccent))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.5)
            .contentShape(Capsule())
    }
}
