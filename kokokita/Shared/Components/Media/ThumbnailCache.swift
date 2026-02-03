import UIKit

/// サムネイル画像のメモリキャッシュ
///
/// - メモリ制限付き（NSCache）で自動解放
/// - サムネイルサイズに縮小してメモリ使用量を削減
/// - スレッドセーフ
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    /// メモリキャッシュ（自動でメモリ圧迫時に解放）
    private let cache = NSCache<NSString, UIImage>()

    /// 最大キャッシュコスト（バイト単位、約50MB）
    private let maxCost = 50 * 1024 * 1024

    /// 最大キャッシュ数
    private let maxCount = 200

    private init() {
        cache.totalCostLimit = maxCost
        cache.countLimit = maxCount

        // 記録が変更された時にキャッシュをクリア
        NotificationCenter.default.addObserver(
            forName: .visitsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearCache()
        }
    }

    /// サムネイルを取得（キャッシュまたは生成）
    ///
    /// - Parameters:
    ///   - path: 画像の相対パス
    ///   - size: サムネイルのサイズ（ポイント）
    /// - Returns: サムネイル画像（なければnil）
    func thumbnail(for path: String, size: CGSize) -> UIImage? {
        let key = cacheKey(path: path, size: size)

        // キャッシュにあればそれを返す
        if let cached = cache.object(forKey: key) {
            return cached
        }

        // なければ生成してキャッシュ
        guard let original = ImageStore.load(path) else {
            return nil
        }

        let thumbnail = generateThumbnail(from: original, targetSize: size)
        if let thumbnail = thumbnail {
            let cost = estimateCost(thumbnail)
            cache.setObject(thumbnail, forKey: key, cost: cost)
        }

        return thumbnail
    }

    /// 非同期でサムネイルを取得
    ///
    /// - Parameters:
    ///   - path: 画像の相対パス
    ///   - size: サムネイルのサイズ（ポイント）
    /// - Returns: サムネイル画像（なければnil）
    func thumbnailAsync(for path: String, size: CGSize) async -> UIImage? {
        let key = cacheKey(path: path, size: size)

        // キャッシュにあればそれを返す
        if let cached = cache.object(forKey: key) {
            return cached
        }

        // バックグラウンドで生成
        return await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return nil }
            guard let original = ImageStore.load(path) else {
                return nil
            }

            let thumbnail = self.generateThumbnail(from: original, targetSize: size)
            if let thumbnail = thumbnail {
                let cost = self.estimateCost(thumbnail)
                await MainActor.run {
                    self.cache.setObject(thumbnail, forKey: key, cost: cost)
                }
            }

            return thumbnail
        }.value
    }

    /// キャッシュをクリア
    func clearCache() {
        cache.removeAllObjects()
    }

    /// 特定の画像のキャッシュを削除
    func removeCache(for path: String) {
        // 全サイズのキャッシュを削除するのは難しいので、
        // 画像削除時はclearCacheを呼ぶか、個別サイズを指定
        // ここでは何もしない（NSCacheが自動で管理）
    }

    // MARK: - Private

    private func cacheKey(path: String, size: CGSize) -> NSString {
        "\(path)_\(Int(size.width))x\(Int(size.height))" as NSString
    }

    /// サムネイルを生成（Retina対応）
    private func generateThumbnail(from image: UIImage, targetSize: CGSize) -> UIImage? {
        let scale = UIScreen.main.scale
        let pixelSize = CGSize(
            width: targetSize.width * scale,
            height: targetSize.height * scale
        )

        // アスペクト比を維持してフィル（scaledToFill相当）
        let widthRatio = pixelSize.width / image.size.width
        let heightRatio = pixelSize.height / image.size.height
        let ratio = max(widthRatio, heightRatio)

        let scaledSize = CGSize(
            width: image.size.width * ratio,
            height: image.size.height * ratio
        )

        // 中央でクロップ
        let drawRect = CGRect(
            x: (pixelSize.width - scaledSize.width) / 2,
            y: (pixelSize.height - scaledSize.height) / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )

        UIGraphicsBeginImageContextWithOptions(pixelSize, true, 1.0)
        defer { UIGraphicsEndImageContext() }

        image.draw(in: drawRect)
        return UIGraphicsGetImageFromCurrentImageContext()
    }

    /// 画像のメモリコストを推定（バイト単位）
    private func estimateCost(_ image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }
}
