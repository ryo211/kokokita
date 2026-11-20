import SwiftUI

/// 到達記録のサーバー送信に関する同意画面。
/// 設定画面の「人気コース表示を有効にする」から表示する。
/// 同意すると、過去の到達済みスポットも含めて送信キューに積まれる
/// doc/server-feature-design.md フェーズ1「同意とオプトアウト」参照
struct MetaCollectionConsentSheet: View {
    var onDismiss: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)

            Text(L.MetaCollection.consentTitle)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text(L.MetaCollection.consentBody)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 12) {
                Button(L.MetaCollection.consentAgree) {
                    agree()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)

                Button(L.MetaCollection.consentDecline) {
                    onDismiss?()
                    dismiss()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 8)
        }
        .padding(28)
        .presentationDetents([.large])
    }

    private func agree() {
        MetaCollectionSettings.shared.isConsented = true
        // 過去の到達済みスポットも含めてキューに積み、送信を試みる（非同期・ベストエフォート）
        Task.detached(priority: .utility) {
            AppContainer.shared.spotArrivalSyncService.enqueueAllHistoricalArrivals()
        }
        onDismiss?()
        dismiss()
    }
}
