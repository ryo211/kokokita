import SwiftUI

/// 座標を表示するバッジコンポーネント
struct CoordinateBadge: View {
    let latitude: Double
    let longitude: Double
    let decimals: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "location.circle")
            Text("\(format(latitude)), \(format(longitude))")
                .font(.caption.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(radius: 1)
    }

    private func format(_ value: Double) -> String {
        String(format: "%.\(decimals)f", value)
    }
}
