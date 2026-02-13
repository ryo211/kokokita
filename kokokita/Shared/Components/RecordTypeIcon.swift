import SwiftUI

/// 記録タイプアイコン
///
/// 通常記録と後付け記録を区別するアイコン。
/// - 通常記録：青いチェックマーク（信頼の青）
/// - 後付け記録：オレンジの工具アイコン（手作りっぽさ）
struct RecordTypeIcon: View {
    let isManualEntry: Bool
    var compact: Bool = false

    private var iconSize: Font {
        compact ? .caption : .subheadline
    }

    var body: some View {
        if isManualEntry {
            // 後付け記録：オレンジの工具アイコン
            Image(systemName: "wrench.adjustable.fill")
                .font(iconSize)
                .foregroundStyle(.orange)
        } else {
            // 通常記録：青いチェックマーク
            Image(systemName: "checkmark.seal.fill")
                .font(iconSize)
                .foregroundStyle(.blue)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack {
            Text("通常記録")
            RecordTypeIcon(isManualEntry: false)
        }
        HStack {
            Text("後付け記録")
            RecordTypeIcon(isManualEntry: true)
        }
        HStack {
            Text("通常記録（コンパクト）")
            RecordTypeIcon(isManualEntry: false, compact: true)
        }
        HStack {
            Text("後付け記録（コンパクト）")
            RecordTypeIcon(isManualEntry: true, compact: true)
        }
    }
    .padding()
}
