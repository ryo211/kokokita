import SwiftUI

/// ページ3: 匿名データ送信の行（タイトル・説明・Toggle）
/// 値は設定画面と同じ MetaCollectionSettings を直接読み書きする。
/// デフォルト値は MetaCollectionSettings 側の既定（オプトアウト方式）に従い、ここでは変更しない
struct OnboardingAnonymousDataRow: View {
    @ObservedObject private var settings = MetaCollectionSettings.shared

    var body: some View {
        Toggle(isOn: $settings.isConsented) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L.Onboarding.anonymousDataTitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.brandText)
                Text(L.Onboarding.anonymousDataDescription)
                    .font(.footnote)
                    .foregroundStyle(Color.brandTextSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(Color.brandAccent)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.brandSurface)
        )
    }
}
