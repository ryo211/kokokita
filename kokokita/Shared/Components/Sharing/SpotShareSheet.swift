import SwiftUI
import MapKit

// MARK: - スポット共有カード（ImageRenderer用）

struct SpotShareCard: View {
    let spot: CourseSpot
    let course: Course
    let coverImage: UIImage?

    static let cardWidth: CGFloat = 390

    var body: some View {
        VStack(spacing: 0) {
            photoSection
            contentSection
        }
        .frame(width: Self.cardWidth)
        .background(Color(.systemBackground))
    }

    private var photoSection: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let img = coverImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [Color.indigo.opacity(0.65), Color.indigo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .frame(width: Self.cardWidth, height: 220)
            .clipped()

            // 下端グラデーション（テキスト読みやすくする）
            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: Self.cardWidth, height: 110)

            // スポット名・コース名（写真下部に重ねる）
            VStack(alignment: .leading, spacing: 3) {
                Text(course.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                Text(spot.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .frame(width: Self.cardWidth, height: 220)
        .clipped()
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let address = spot.address, !address.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.indigo)
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            if let desc = spot.spotDescription, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            // アプリロゴフッター
            HStack(spacing: 0) {
                Image("kokokita-app-icon-clearBlueDeep")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(L.App.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.indigo)
                    .padding(.leading, 8)
                Spacer()
                AppStoreBadgeView()
            }
        }
        .padding(16)
        .frame(width: Self.cardWidth, alignment: .leading)
    }
}

// MARK: - コース共有カード（ImageRenderer用）

struct CourseShareCard: View {
    let course: Course
    let coverImage: UIImage?

    static let cardWidth: CGFloat = 390

    var body: some View {
        VStack(spacing: 0) {
            photoSection
            contentSection
        }
        .frame(width: Self.cardWidth)
        .background(Color(.systemBackground))
    }

    private var photoSection: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let img = coverImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [Color.indigo.opacity(0.6), Color.indigo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .frame(width: Self.cardWidth, height: 220)
            .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: Self.cardWidth, height: 120)

            VStack(alignment: .leading, spacing: 4) {
                Text(course.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(L.Share.spotCountLabel(course.totalSpotCount))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .frame(width: Self.cardWidth, height: 220)
        .clipped()
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let summary = course.summary, !summary.isEmpty {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack(spacing: 0) {
                Image("kokokita-app-icon-clearBlueDeep")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(L.App.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.indigo)
                    .padding(.leading, 8)
                Spacer()
                AppStoreBadgeView()
            }
        }
        .padding(16)
        .frame(width: Self.cardWidth, alignment: .leading)
    }
}

// MARK: - スポット共有プレビューシート

struct SpotSharePreviewSheet: View {
    let spot: CourseSpot
    let course: Course
    @Environment(\.dismiss) private var dismiss

    @State private var coverImage: UIImage? = nil
    @State private var mapImage: UIImage? = nil
    @State private var renderedShareImage: UIImage? = nil
    @State private var isRendering = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    textPreviewSection
                    imagePreviewSection
                    if spot.hasValidCoordinate {
                        mapPreviewSection
                    }
                }
                .padding(.vertical, 16)
            }
            .navigationTitle(L.Share.previewTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L.Common.cancel) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        presentShareSheet(buildShareItems())
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .fontWeight(.semibold)
                    }
                    .disabled(renderedShareImage == nil)
                }
            }
        }
        .task {
            await loadImages()
            await renderShareImage()
        }
    }

    // MARK: - テキストプレビュー

    private var textPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L.Share.textLabel, systemImage: "text.quote")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(shareText)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal)
    }

    // MARK: - 共有画像プレビュー

    private var imagePreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L.Share.imageSection, systemImage: "photo")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if let rendered = renderedShareImage {
                Image(uiImage: rendered)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal)
                    .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
            } else if isRendering {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(40)
            }
        }
    }

    // MARK: - 地図プレビュー

    @ViewBuilder
    private var mapPreviewSection: some View {
        if let mapImg = mapImage {
            VStack(alignment: .leading, spacing: 8) {
                Label(L.Share.mapTitle, systemImage: "map")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                Image(uiImage: mapImg)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal)
                    .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
            }
        }
    }

    // MARK: - ヘルパー

    private var shareText: String {
        L.Share.spotShareText(course.title, spot.name)
    }

    private func buildShareItems() -> [Any] {
        var items: [Any] = [shareText]
        if let img = renderedShareImage { items.append(img) }
        if let map = mapImage { items.append(map) }
        return items
    }

    @MainActor
    private func loadImages() async {
        if let path = spot.localCoverImagePath {
            coverImage = LocalImageStorage.shared.load(from: path)
        } else if let urlStr = spot.coverImageUrl, let url = URL(string: urlStr) {
            coverImage = await downloadImage(from: url)
        }

        if spot.hasValidCoordinate {
            let coord = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
            let radius = spot.recognitionRadiusMeters ?? course.recognitionRadiusMeters
            mapImage = await makeMapSnapshot(coordinate: coord, radius: radius)
        }
    }

    @MainActor
    private func renderShareImage() async {
        isRendering = true
        defer { isRendering = false }
        let view = SpotShareCard(spot: spot, course: course, coverImage: coverImage)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0
        renderedShareImage = renderer.uiImage
    }

    private func downloadImage(from url: URL) async -> UIImage? {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return UIImage(data: data)
    }

    private func makeMapSnapshot(coordinate: CLLocationCoordinate2D, radius: Double) async -> UIImage? {
        let options = MKMapSnapshotter.Options()
        let displayRadius = max(radius * 8, 500)
        options.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: displayRadius,
            longitudinalMeters: displayRadius
        )
        options.size = CGSize(width: SpotShareCard.cardWidth, height: 200)
        options.scale = UIScreen.main.scale
        options.mapType = .standard
        options.showsBuildings = true
        guard let snapshot = try? await MKMapSnapshotter(options: options).start() else { return nil }
        let pinPoint = snapshot.point(for: coordinate)
        let size = options.size
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            snapshot.image.draw(at: .zero)
            let pinSize: CGFloat = 30
            let pinConfig = UIImage.SymbolConfiguration(pointSize: pinSize, weight: .bold)
            let pin = UIImage(systemName: "mappin.circle.fill", withConfiguration: pinConfig)?
                .withTintColor(.systemIndigo, renderingMode: .alwaysOriginal)
            pin?.draw(at: CGPoint(x: pinPoint.x - pinSize / 2, y: pinPoint.y - pinSize))
        }
    }
}

// MARK: - コース共有プレビューシート

struct CourseSharePreviewSheet: View {
    let course: Course
    @Environment(\.dismiss) private var dismiss

    @State private var coverImage: UIImage? = nil
    @State private var renderedShareImage: UIImage? = nil
    @State private var isRendering = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // テキストプレビュー
                    VStack(alignment: .leading, spacing: 8) {
                        Label(L.Share.textLabel, systemImage: "text.quote")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(shareText)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal)

                    // 共有画像プレビュー
                    VStack(alignment: .leading, spacing: 8) {
                        Label(L.Share.imageSection, systemImage: "photo")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        if let rendered = renderedShareImage {
                            Image(uiImage: rendered)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .padding(.horizontal)
                                .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
                        } else if isRendering {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(40)
                        }
                    }
                }
                .padding(.vertical, 16)
            }
            .navigationTitle(L.Share.previewTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L.Common.cancel) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        presentShareSheet(buildShareItems())
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .fontWeight(.semibold)
                    }
                    .disabled(renderedShareImage == nil)
                }
            }
        }
        .task {
            await loadCoverImage()
            await renderShareImage()
        }
    }

    private var shareText: String {
        L.Share.courseShareText(course.title)
    }

    private func buildShareItems() -> [Any] {
        var items: [Any] = [shareText]
        if let img = renderedShareImage { items.append(img) }
        return items
    }

    @MainActor
    private func loadCoverImage() async {
        if let path = course.localCoverImagePath {
            coverImage = LocalImageStorage.shared.load(from: path)
        } else if let urlStr = course.coverImageUrl, let url = URL(string: urlStr) {
            guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
            coverImage = UIImage(data: data)
        }
    }

    @MainActor
    private func renderShareImage() async {
        isRendering = true
        defer { isRendering = false }
        let view = CourseShareCard(course: course, coverImage: coverImage)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0
        renderedShareImage = renderer.uiImage
    }
}

// MARK: - App Store バッジビュー

/// Assets.xcassets に "badge_app_store" という名前で公式バッジ画像を追加すると自動的に使用される。
/// 画像が未登録の場合はコードで再現したバッジを表示する。
private struct AppStoreBadgeView: View {
    var body: some View {
        if UIImage(named: "badge_app_store") != nil {
            Image("badge_app_store")
                .resizable()
                .scaledToFit()
                .frame(height: 30)
        } else {
            // 公式バッジ未登録時のフォールバック
            HStack(spacing: 5) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 18, weight: .regular))
                VStack(alignment: .leading, spacing: 0) {
                    Text("Download on the")
                        .font(.system(size: 7.5, weight: .regular))
                    Text("App Store")
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

// MARK: - UIActivityViewController を直接 present するヘルパー

/// SwiftUI の .sheet 経由では二重シート競合が発生するため、UIKit レイヤーで直接 present する
private func presentShareSheet(_ items: [Any]) {
    let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
    vc.excludedActivityTypes = [.assignToContact, .print, .saveToCameraRoll, .addToReadingList]

    guard let scene = UIApplication.shared.connectedScenes
        .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
          let window = scene.windows.first(where: { $0.isKeyWindow }) else { return }

    // iPad: ポップオーバー設定
    if let popover = vc.popoverPresentationController {
        popover.sourceView = window
        popover.sourceRect = CGRect(
            x: window.bounds.midX, y: window.bounds.midY,
            width: 0, height: 0
        )
        popover.permittedArrowDirections = []
    }

    // 最前面の ViewController を探して present
    var topVC = window.rootViewController
    while let presented = topVC?.presentedViewController {
        topVC = presented
    }
    topVC?.present(vc, animated: true)
}
