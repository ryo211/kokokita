import SwiftUI

/// 薄青色のアクセントカードスタイル
///
/// 使用例:
/// ```swift
/// Text("Hello")
///     .padding()
///     .accentCardStyle()
/// ```
struct AccentCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 1)
                    }
            )
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

extension View {
    /// 薄青色のアクセントカードスタイルを適用
    func accentCardStyle() -> some View {
        modifier(AccentCardModifier())
    }
}

/// 薄青色のアクセントカードコンテナ
///
/// 使用例:
/// ```swift
/// AccentCard {
///     Text("Hello")
/// }
/// ```
struct AccentCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .accentCardStyle()
    }
}
