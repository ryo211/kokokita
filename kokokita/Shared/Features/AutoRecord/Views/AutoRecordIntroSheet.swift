import SwiftUI

/// 自動記録機能を初めてONにした瞬間だけ表示する説明シート
/// 仕組みの簡単な説明とAlways許可が必要な旨を伝え、閉じると許可ダイアログに進む
struct AutoRecordIntroSheet: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)

            Text(L.AutoRecord.introTitle)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text(L.AutoRecord.introMechanismDescription)
                .font(.body)
                .multilineTextAlignment(.center)

            Text(L.AutoRecord.introPermissionNotice)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(L.AutoRecord.introDismissAction) {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .padding(32)
        .presentationDetents([.medium])
    }
}
