import SwiftUI

// アプリのルートビュー
// AppModeManager を参照して初回起動時のモード選択画面を表示し、
// モードに応じて RecordRootTabView または PilgrimageRootTabView に分岐する
struct RootView: View {
    @StateObject private var modeManager = AppModeManager()

    var body: some View {
        Group {
            if !modeManager.hasSeenModeSelection {
                // 初回起動: モード選択画面を表示
                ModeSelectionView()
                    .environmentObject(modeManager)
            } else {
                switch modeManager.mode {
                case .record:
                    // 記録モード: 既存の RootTabView
                    RootTabView()
                case .pilgrimage:
                    // 巡礼モード: 新しい PilgrimageRootTabView
                    PilgrimageRootTabView()
                        .environmentObject(modeManager)
                }
            }
        }
        .environmentObject(modeManager)
    }
}
