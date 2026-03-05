import SwiftUI

// アプリのルートビュー
// AppModeManager を参照して初回起動時のモード選択画面を表示し、
// モードに応じて RootTabView または PilgrimageRootTabView に分岐する
struct RootView: View {
    @StateObject private var modeManager = AppModeManager()
    /// 現在描画しているモード（アニメーション中は切り替えタイミングを制御するため modeManager.mode と一時的にズレる）
    @State private var renderMode: AppMode = RootView.savedMode()
    @State private var flipAngle: Double = 0

    var body: some View {
        Group {
            if !modeManager.hasSeenModeSelection {
                // 初回起動: モード選択画面を表示
                ModeSelectionView()
                    .environmentObject(modeManager)
            } else {
                modeContent(for: renderMode)
                    .rotation3DEffect(
                        .degrees(flipAngle),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.4
                    )
            }
        }
        .environmentObject(modeManager)
        .onChange(of: modeManager.mode) { _, newMode in
            performFlip(to: newMode)
        }
    }

    // MARK: - コンテンツ分岐

    @ViewBuilder
    private func modeContent(for mode: AppMode) -> some View {
        switch mode {
        case .record:
            RootTabView()
        case .pilgrimage:
            PilgrimageRootTabView()
                .environmentObject(modeManager)
        }
    }

    // MARK: - フリップアニメーション

    private func performFlip(to newMode: AppMode) {
        // Phase 1: 現在のビューを90°回転（画面端に消える）
        withAnimation(.easeIn(duration: 0.2)) {
            flipAngle = 90
        }
        // Phase 2: コンテンツ切り替え → 反対側から登場
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            renderMode = newMode
            flipAngle = -90
            // Phase 3: 新しいビューを0°に戻す（正面に現れる）
            withAnimation(.easeOut(duration: 0.2)) {
                flipAngle = 0
            }
        }
    }

    // MARK: - 初期モード取得（UserDefaults から直接読み取り）

    private static func savedMode() -> AppMode {
        let raw = UserDefaults.standard.string(forKey: "appMode") ?? AppMode.record.rawValue
        return AppMode(rawValue: raw) ?? .record
    }
}
