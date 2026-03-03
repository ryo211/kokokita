import SwiftUI

/// 後付け記録バッジ
///
/// 後付け記録であることを示すオレンジ色のカプセル型バッジ。
/// pencil.circleアイコン + "後付け" テキストを表示する。
struct ManualEntryBadge: View {
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 2 : 3) {
            Image(systemName: "pencil.circle.fill")
                .font(compact ? .caption2 : .caption)
            Text(L.ManualEntry.badge)
                .font(compact ? .caption2 : .caption)
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 5 : 6)
        .padding(.vertical, compact ? 2 : 3)
        .background(
            Capsule()
                .fill(Color.orange)
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        ManualEntryBadge()
        ManualEntryBadge(compact: true)
    }
    .padding()
}
