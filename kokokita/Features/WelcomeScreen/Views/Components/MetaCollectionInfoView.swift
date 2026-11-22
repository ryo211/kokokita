import SwiftUI

/// ウェルカム画面: 匿名データ送信（到達記録・コース閲覧等）についての説明ブロック。
/// システム許可ダイアログを伴わない情報提供のみで、デフォルトでオン（設定からいつでもオフにできる）
struct MetaCollectionInfoView: View {
    var body: some View {
        HStack(alignment: .top, spacing: UIConstants.Spacing.extraLarge) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 32))
                .foregroundStyle(Color.accentColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: UIConstants.Spacing.small) {
                Text(L.Welcome.metaCollectionTitle)
                    .font(.headline)
                Text(L.Welcome.metaCollectionDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}
