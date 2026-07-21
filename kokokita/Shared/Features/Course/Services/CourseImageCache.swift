import SwiftUI

// コース画像のメモリキャッシュ（NSCache ベース）
// AsyncImage は NSURLCache を使うが TTL やヘッダー次第でヒットしない場合があるため
// アプリ内で UIImage を独自キャッシュして即座に表示できるようにする
final class CourseImageCache {
    static let shared = CourseImageCache()
    private let cache = NSCache<NSString, UIImage>()
    private init() {
        cache.countLimit = 100
    }

    func get(_ url: URL) -> UIImage? {
        cache.object(forKey: url.absoluteString as NSString)
    }

    func set(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url.absoluteString as NSString)
    }
}

// キャッシュ付きコース画像ビュー
// ローカル保存画像 → キャッシュ → URL ダウンロード の順で優先
// ダウンロード完了後は NSCache に保存して次回即座に表示
struct CachedCourseImage: View {
    let url: URL
    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let uiImage {
                Color.clear.overlay {
                    Image(uiImage: uiImage).resizable().scaledToFill()
                }
                .clipped()
                .transition(.opacity.animation(.easeIn(duration: 0.2)))
            } else {
                Color.clear
            }
        }
        .task(id: url) {
            if let cached = CourseImageCache.shared.get(url) {
                uiImage = cached
                return
            }
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data) else { return }
            CourseImageCache.shared.set(image, for: url)
            uiImage = image
        }
    }
}
