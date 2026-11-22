import SwiftUI

/// 匿名データ送信（到達記録・コース閲覧・お気に入り）についての説明シート。
/// 設定画面の「詳しく見る」から開く読み物専用のシート。送信のオン/オフ自体は
/// 設定画面のトグルで行うため、ここには同意/拒否ボタンは置かない
/// doc/server-feature-design.md フェーズ1「同意とオプトアウト」参照
struct MetaCollectionInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)

            Text(L.MetaCollection.infoTitle)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text(L.MetaCollection.infoBody)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Button(L.MetaCollection.infoClose) {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
        .padding(28)
        .presentationDetents([.large])
    }
}
