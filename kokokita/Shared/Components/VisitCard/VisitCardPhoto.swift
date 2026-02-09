import SwiftUI

/// 記録カード用の写真サムネイル表示コンポーネント
///
/// 使用例:
/// ```swift
/// // 縦型カード用（幅いっぱい、固定高さ）
/// VisitCardPhoto(
///     paths: ["photo1.jpg", "photo2.jpg"],
///     width: 160,
///     height: 100,
///     cornerRadius: 10
/// )
///
/// // 横型カード用（正方形）
/// VisitCardPhoto(
///     paths: ["photo1.jpg"],
///     size: 80,
///     cornerRadius: 10
/// )
/// ```
struct VisitCardPhoto: View {
    /// 写真パスの配列（最初の1枚のみ表示）
    let paths: [String]

    /// 幅
    let width: CGFloat

    /// 高さ
    let height: CGFloat

    /// 角丸
    let cornerRadius: CGFloat

    /// プレースホルダーの背景色
    var placeholderBackground: Color = Color(.systemGray5)

    /// プレースホルダーアイコン色
    var placeholderIconColor: Color = .secondary

    // MARK: - Initializers

    /// 縦型カード用（幅と高さを個別指定）
    init(
        paths: [String],
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat = VisitCardStyle.verticalPhotoCornerRadius,
        placeholderBackground: Color = Color(.systemGray5),
        placeholderIconColor: Color = .secondary
    ) {
        self.paths = paths
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.placeholderBackground = placeholderBackground
        self.placeholderIconColor = placeholderIconColor
    }

    /// 横型カード用（正方形）
    init(
        paths: [String],
        size: CGFloat,
        cornerRadius: CGFloat = VisitCardStyle.horizontalPhotoCornerRadius,
        placeholderBackground: Color = Color(.systemGray5),
        placeholderIconColor: Color = .secondary
    ) {
        self.paths = paths
        self.width = size
        self.height = size
        self.cornerRadius = cornerRadius
        self.placeholderBackground = placeholderBackground
        self.placeholderIconColor = placeholderIconColor
    }

    // MARK: - Body

    var body: some View {
        Group {
            if let firstPath = paths.first {
                // 写真がある場合は非同期サムネイルで表示
                AsyncThumbnailImage(
                    path: firstPath,
                    size: CGSize(width: width, height: height),
                    cornerRadius: cornerRadius,
                    placeholderBackground: placeholderBackground,
                    placeholderIconColor: placeholderIconColor
                )
            } else {
                // 写真がない場合のプレースホルダー
                placeholder
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    // MARK: - Placeholder

    @ViewBuilder
    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(placeholderBackground)

            Image(systemName: "photo")
                .font(.title2)
                .foregroundStyle(placeholderIconColor)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("写真あり") {
    VisitCardPhoto(
        paths: ["sample.jpg"],
        width: 160,
        height: 100
    )
    .padding()
}

#Preview("写真なし（プレースホルダー）") {
    VisitCardPhoto(
        paths: [],
        width: 160,
        height: 100
    )
    .padding()
}

#Preview("横型（正方形）") {
    VisitCardPhoto(
        paths: [],
        size: 80
    )
    .padding()
}
#endif
