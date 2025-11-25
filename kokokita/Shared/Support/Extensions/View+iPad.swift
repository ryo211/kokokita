import SwiftUI
import UIKit

extension View {
    /// iPadでシートをより大きく表示するためのモディファイア
    func iPadSheetSize() -> some View {
        self
            .modifier(iPadSheetSizeModifier())
    }
}

private struct iPadSheetSizeModifier: ViewModifier {
    func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPadの場合：コンテンツに最小サイズを設定し、背景とpresentationDetentsを調整
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
            // iPhoneの場合：標準の.large
            content
                .presentationDetents([.large])
        }
    }
}
