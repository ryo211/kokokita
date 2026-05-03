import SwiftUI

// スポットのサムネイル画像（ローカル画像優先 → リモートURL → プレースホルダー）
struct SpotThumbnailView: View {
    let spot: CourseSpot
    var size: CGFloat = 52
    var cornerRadius: CGFloat = 10

    var body: some View {
        Group {
            if let uiImage = spot.localCoverImagePath.flatMap({ LocalImageStorage.shared.load(from: $0) }) {
                // ローカル保存画像
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let urlStr = spot.coverImageUrl, let url = URL(string: urlStr) {
                // リモート画像
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var placeholder: some View {
        ZStack {
            Color(uiColor: .systemGray5)
            Image(systemName: spot.isCheckedIn ? "checkmark.circle.fill" : "mappin.circle")
                .font(.system(size: size * 0.38))
                .foregroundStyle(Color(uiColor: .systemGray3))
        }
    }
}
