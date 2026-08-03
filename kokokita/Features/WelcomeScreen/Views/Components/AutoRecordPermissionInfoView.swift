import SwiftUI

/// ウェルカム画面: 自動記録機能を使うには「常に許可」が必要な旨の説明ブロック
struct AutoRecordPermissionInfoView: View {
    var body: some View {
        HStack(alignment: .top, spacing: UIConstants.Spacing.extraLarge) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 32))
                .foregroundStyle(Color.accentColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: UIConstants.Spacing.small) {
                Text(L.Welcome.autoRecordPermissionTitle)
                    .font(.headline)
                Text(L.Welcome.autoRecordPermissionDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}
