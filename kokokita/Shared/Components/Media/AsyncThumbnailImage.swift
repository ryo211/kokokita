import SwiftUI

/// 非同期でサムネイルを読み込んで表示するView
///
/// - メインスレッドをブロックしない
/// - キャッシュを活用して高速表示
/// - 読み込み中はプレースホルダーを表示
struct AsyncThumbnailImage: View {
    /// 画像の相対パス
    let path: String

    /// 表示サイズ
    let size: CGSize

    /// 角丸
    var cornerRadius: CGFloat = 8

    /// プレースホルダー背景色
    var placeholderBackground: Color = Color(.systemGray5)

    /// プレースホルダーアイコン色
    var placeholderIconColor: Color = .secondary

    /// 読み込んだ画像
    @State private var image: UIImage?

    /// 読み込み中フラグ
    @State private var isLoading = false

    /// 最後に読み込んだパス（パス変更検知用）
    @State private var loadedPath: String?

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: path) {
            await loadThumbnail()
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(placeholderBackground)

            if isLoading {
                // 読み込み中（必要に応じてProgressViewに変更可能）
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(placeholderIconColor.opacity(0.5))
            } else {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(placeholderIconColor)
            }
        }
    }

    private func loadThumbnail() async {
        // パスが変わった場合は前の画像をクリアして再読み込み
        if loadedPath == path && image != nil {
            return
        }

        isLoading = true
        defer { isLoading = false }

        // まずキャッシュを同期チェック（高速）
        if let cached = ThumbnailCache.shared.thumbnail(for: path, size: size) {
            self.image = cached
            self.loadedPath = path
            return
        }

        // キャッシュになければ非同期で生成
        if let thumbnail = await ThumbnailCache.shared.thumbnailAsync(for: path, size: size) {
            await MainActor.run {
                self.image = thumbnail
                self.loadedPath = path
            }
        } else {
            self.loadedPath = path
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("非同期サムネイル") {
    VStack(spacing: 16) {
        AsyncThumbnailImage(
            path: "sample.jpg",
            size: CGSize(width: 80, height: 80)
        )

        AsyncThumbnailImage(
            path: "nonexistent.jpg",
            size: CGSize(width: 80, height: 80)
        )
    }
    .padding()
}
#endif
