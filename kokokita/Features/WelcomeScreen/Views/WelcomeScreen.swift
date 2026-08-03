import SwiftUI

// 初回起動時に表示するウェルカム画面
// 位置情報許可（WhenInUse/Always）に関する説明のみを表示し、
// 表示中に裏でコース初期同期を進める。アプリの使い方は実画面のコーチマークに委ねる
struct WelcomeScreen: View {
    @Environment(AppModeManager.self) private var modeManager
    @State private var store = WelcomeStore()

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image("kokokita_irodori_blue")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)

                Text(L.Welcome.title)
                    .font(.largeTitle.bold())
            }

            Spacer()

            // 位置情報許可の説明（2ブロック常時表示、スワイプ不要）
            // 機能紹介ではなく「利用に必要な設定」という文脈で見せる
            VStack(alignment: .leading, spacing: UIConstants.Spacing.extraLarge) {
                Text(L.Welcome.setupSectionTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: UIConstants.Spacing.xxLarge) {
                    LocationPermissionInfoView()
                    AutoRecordPermissionInfoView()

                    Text(L.Welcome.permissionDialogNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, UIConstants.Spacing.xxLarge)

            Spacer()

            // コース同期プログレスバー ＋ はじめるボタン
            VStack(spacing: UIConstants.Spacing.extraLarge) {
                CourseSyncProgressBar(progress: store.syncProgress)

                WelcomeStartButton(isEnabled: store.isSyncComplete) {
                    store.requestLocationPermission()
                    modeManager.markWelcomeSeen()
                }
            }
            .padding(.horizontal, UIConstants.Spacing.xxLarge)
            .padding(.bottom, UIConstants.Spacing.xxLarge)
        }
        .task {
            store.startInitialCourseSync()
        }
    }
}
