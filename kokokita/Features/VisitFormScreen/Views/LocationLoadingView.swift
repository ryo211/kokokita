import SwiftUI

/// 位置情報取得中のローディング画面
struct LocationLoadingView: View {
    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))

            VStack(spacing: 8) {
                Text("位置情報を取得中...")
                    .font(.headline)

                Text("しばらくお待ちください")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    LocationLoadingView()
}
