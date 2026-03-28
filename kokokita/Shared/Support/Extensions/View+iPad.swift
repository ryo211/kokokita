import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension View {
    /// iPadでシートをより大きく表示するためのモディファイア
    /// - Parameter iPhoneDetents: iPhoneで使用するdetents（デフォルト: [.large]）
    func iPadSheetSize(iPhoneDetents: Set<PresentationDetent> = [.large]) -> some View {
        self.modifier(iPadSheetSizeModifier(iPhoneDetents: iPhoneDetents))
    }
}

private struct iPadSheetSizeModifier: ViewModifier {
    let iPhoneDetents: Set<PresentationDetent>

    @ViewBuilder
    func body(content: Content) -> some View {
#if canImport(UIKit)
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPadの場合：最小サイズを確保し、常にlarge表示
            content
                .frame(
                    minWidth: UIScreen.main.bounds.width * 0.7,
                    maxWidth: .infinity,
                    minHeight: UIScreen.main.bounds.height * 0.6,
                    maxHeight: .infinity
                )
                .presentationDetents([.large])
                .presentationBackground(.regularMaterial)
        } else {
            // iPhoneの場合：呼び出し側で指定されたdetents
            content
                .presentationDetents(iPhoneDetents)
        }
#else
        content
            .presentationDetents(iPhoneDetents)
#endif
    }
}
