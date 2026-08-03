import SwiftUI

/// ウェルカム画面: コース同期完了まで非活性、完了後に活性化する「はじめる」ボタン
struct WelcomeStartButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(L.Welcome.startButton)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, UIConstants.Spacing.large)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!isEnabled)
    }
}
