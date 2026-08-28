import SwiftUI

/// ウェルカム画面: コース初期同期の進捗をダウンロードバー風に表示する
struct CourseSyncProgressBar: View {
    let progress: Double

    private var isComplete: Bool { progress >= 1.0 }

    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.small) {
            ProgressView(value: progress)
                .tint(Color.accentColor)

            Text(isComplete ? L.Welcome.syncProgressCompleteLabel : L.Welcome.syncProgressLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
