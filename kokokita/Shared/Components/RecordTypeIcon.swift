import SwiftUI

/// 記録タイプバッジ
///
/// 通常記録と後付け記録を区別するバッジ。
/// ココキタボタン・追加ボタンのデザインを踏襲。
/// - 証明付き記録：`checkmark.seal.fill`（青）
/// - 後付け記録：オレンジの時計アイコン
struct RecordTypeIcon: View {
    let isManualEntry: Bool
    var compact: Bool = false

    /// バッジサイズ
    private var badgeSize: CGFloat {
        compact ? 20 : 24
    }

    /// シンボルサイズ
    private var symbolSize: CGFloat {
        compact ? 13 : 15
    }

    var body: some View {
        ZStack {
            if isManualEntry {
                Image(systemName: "clock.fill")
                    .font(.system(size: symbolSize, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.orange.opacity(0.95),
                                Color.orange.opacity(0.75)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .offset(y: compact ? 0.3 : 0.5)
            } else {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: compact ? 13 : 16, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .offset(y: compact ? 0.3 : 0.5)
            }
        }
        .frame(width: badgeSize, height: badgeSize)
    }

}

#Preview {
    VStack(spacing: 20) {
        HStack {
            Text("証明付き記録（青）")
            RecordTypeIcon(isManualEntry: false)
        }
        HStack {
            Text("後付け記録（オレンジ）")
            RecordTypeIcon(isManualEntry: true)
        }
        HStack {
            Text("証明付き記録（コンパクト）")
            RecordTypeIcon(isManualEntry: false, compact: true)
        }
        HStack {
            Text("後付け記録（コンパクト）")
            RecordTypeIcon(isManualEntry: true, compact: true)
        }
    }
    .padding()
}
