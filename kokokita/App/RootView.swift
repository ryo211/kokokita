import SwiftUI

// アプリのルートビュー
// AppModeManager を参照して初回起動時のウェルカム画面を表示し、
// モードに応じて RootTabView または PilgrimageRootTabView を表示する
//
// 以前は modeManager.mode を switch して RootTabView()/PilgrimageRootTabView() を
// 都度生成し直しており、切替のたびに RecordingController・CourseListStore・
// 各種GeometryReaderを含むビュー階層をまるごと破棄→再構築していたことが重さの本質だった。
// そのため両モードを常時マウントし、表示切替（クロスフェード）だけで済む設計に変更した。
// 3D回転フリップも試したが、再構築コストをなくした状態でも回転そのものの描画コストで
// カクつきが残ったため、単純なフェードに留めている。
// トレードオフとして、一度でも両モードを開くとその状態（位置情報・コース一覧・
// 通知購読など）はアプリ終了までメモリ上に残り続ける。
struct RootView: View {
    @State private var modeManager = AppModeManager()

    var body: some View {
        Group {
            if !modeManager.hasSeenWelcome {
                // 初回起動: ウェルカム画面を表示
                WelcomeScreen()
                    .environment(modeManager)
            } else {
                ZStack {
                    RootTabView(isActiveMode: modeManager.mode == .record)
                        .modeVisibility(isActive: modeManager.mode == .record)

                    PilgrimageRootTabView(isActiveMode: modeManager.mode == .pilgrimage)
                        .environment(modeManager)
                        .modeVisibility(isActive: modeManager.mode == .pilgrimage)
                }
                .animation(.easeInOut(duration: 0.2), value: modeManager.mode)
            }
        }
        .environment(modeManager)
    }
}

private extension View {
    /// 非アクティブ側は不可視化・操作無効化・アクセシビリティから除外するだけで、
    /// ビュー階層自体は破棄しない（常駐させることで切替時の再構築コストをゼロにする）
    func modeVisibility(isActive: Bool) -> some View {
        self
            .opacity(isActive ? 1 : 0)
            .allowsHitTesting(isActive)
            .accessibilityHidden(!isActive)
    }
}
