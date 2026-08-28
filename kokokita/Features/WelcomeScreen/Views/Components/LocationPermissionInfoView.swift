import SwiftUI

/// ウェルカム画面: 記録・近隣スポット探索に位置情報の使用中の許可が必要な旨の説明ブロック
struct LocationPermissionInfoView: View {
    var body: some View {
        HStack(alignment: .top, spacing: UIConstants.Spacing.extraLarge) {
            Image(systemName: "location.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(Color.accentColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: UIConstants.Spacing.small) {
                Text(L.Welcome.locationPermissionTitle)
                    .font(.headline)
                Text(L.Welcome.locationPermissionDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}
