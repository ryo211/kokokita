import SwiftUI

/// 対象のボタンをパルス発光させる軽量なアニメーション修飾子
/// TipKitのpopoverでは視覚的な強調ができないため、コーチマークの「次にタップすべきボタン」を示す目的で使う
struct PulsingHighlight: ViewModifier {
    let isActive: Bool
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .shadow(color: .accentColor.opacity(isPulsing ? 0.9 : 0), radius: 10)
            .scaleEffect(isPulsing ? 1.08 : 1.0)
            .onAppear {
                updatePulsing(isActive)
            }
            .onChange(of: isActive) { _, newValue in
                updatePulsing(newValue)
            }
    }

    /// 開始・停止どちらも明示的にwithAnimationで包む。
    /// 停止側をwithAnimationなしで行うと、進行中の.repeatForeverアニメーションが
    /// キャンセルされず光り続けたままになることがあったため
    private func updatePulsing(_ active: Bool) {
        if active {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        } else {
            withAnimation(.easeOut(duration: 0.2)) {
                isPulsing = false
            }
        }
    }
}

extension View {
    /// 初回チュートリアルのコーチマーク対象ボタンをパルス発光させる
    func pulsingHighlight(isActive: Bool) -> some View {
        modifier(PulsingHighlight(isActive: isActive))
    }
}
