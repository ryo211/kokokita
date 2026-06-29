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

            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: Self.cardWidth, height: 110)

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
    @State private var editableText: String = ""
    @State private var showMapEditor = false

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
        .sheet(isPresented: $showMapEditor) {
            if spot.hasValidCoordinate {
                let coord = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
                let radius = spot.recognitionRadiusMeters ?? course.recognitionRadiusMeters
                let displayRadius = max(radius * 8, 500)
                let region = MKCoordinateRegion(
                    center: coord,
                    latitudinalMeters: displayRadius,
                    longitudinalMeters: displayRadius
                )
                ShareMapEditorSheet(spots: course.spots, initialRegion: region) { image in
                    mapImage = image
                }
            }
        }
        .task {
            editableText = L.Share.spotShareText(course.title, spot.name)
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
            TextEditor(text: $editableText)
                .font(.subheadline)
                .frame(minHeight: 80)
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                .scrollContentBackground(.hidden)
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
        VStack(alignment: .leading, spacing: 8) {
            Label(L.Share.mapTitle, systemImage: "map")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if let mapImg = mapImage {
                editableMapThumbnail(image: mapImg)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(24)
            }
        }
    }

    // MARK: - ヘルパー

    private func buildShareItems() -> [Any] {
        var items: [Any] = [editableText]
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
            let displayRadius = max(radius * 8, 500)
            let region = MKCoordinateRegion(center: coord, latitudinalMeters: displayRadius, longitudinalMeters: displayRadius)
            let orderNumber = (course.spots.firstIndex(where: { $0.id == spot.id }) ?? 0) + 1
            mapImage = await makeShareMapSnapshot(region: region, spots: [spot], orderNumbers: [0: orderNumber])
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
}

// MARK: - コース共有プレビューシート

struct CourseSharePreviewSheet: View {
    let course: Course
    @Environment(\.dismiss) private var dismiss

    @State private var coverImage: UIImage? = nil
    @State private var mapImage: UIImage? = nil
    @State private var renderedShareImage: UIImage? = nil
    @State private var isRendering = false
    @State private var editableText: String = ""
    @State private var showMapEditor = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // テキストプレビュー
                    VStack(alignment: .leading, spacing: 8) {
                        Label(L.Share.textLabel, systemImage: "text.quote")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextEditor(text: $editableText)
                            .font(.subheadline)
                            .frame(minHeight: 80)
                            .padding(10)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                            .scrollContentBackground(.hidden)
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

                    // 地図プレビュー
                    VStack(alignment: .leading, spacing: 8) {
                        Label(L.Share.mapTitle, systemImage: "map")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        if let mapImg = mapImage {
                            editableMapThumbnail(image: mapImg)
                        } else {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(24)
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
        .sheet(isPresented: $showMapEditor) {
            ShareMapEditorSheet(
                spots: course.spots,
                initialRegion: spotsFitRegion(course.spots)
            ) { image in
                mapImage = image
            }
        }
        .task {
            editableText = L.Share.courseShareText(course.title)
            await loadCoverImage()
            await renderShareImage()
            await generateCourseMap()
        }
    }

    private func buildShareItems() -> [Any] {
        var items: [Any] = [editableText]
        if let img = renderedShareImage { items.append(img) }
        if let map = mapImage { items.append(map) }
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

    @MainActor
    private func generateCourseMap() async {
        let spots = course.spots
        guard !spots.isEmpty else { return }
        let region = spotsFitRegion(spots)
        let orderMap = Dictionary(uniqueKeysWithValues: spots.enumerated().map { ($0.offset, $0.offset + 1) })
        mapImage = await makeShareMapSnapshot(region: region, spots: spots, orderNumbers: orderMap)
    }
}

// MARK: - 地図サムネイル（タップで編集）

/// 共有プレビューシートで使う地図サムネイル共通ビュー
private func editableMapThumbnail(image: UIImage, action: (() -> Void)? = nil) -> some View {
    Button {
        action?()
    } label: {
        ZStack(alignment: .bottomTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // 編集ヒントバッジ
            Label(L.Share.mapEditHint, systemImage: "pencil")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(10)
        }
    }
    .buttonStyle(.plain)
    .padding(.horizontal)
    .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
}

// MARK: - View Extension（地図サムネイル呼び出しを簡潔に）

extension SpotSharePreviewSheet {
    func editableMapThumbnail(image: UIImage) -> some View {
        Sharing.editableMapThumbnail(image: image) { showMapEditor = true }
    }
}

extension CourseSharePreviewSheet {
    func editableMapThumbnail(image: UIImage) -> some View {
        Sharing.editableMapThumbnail(image: image) { showMapEditor = true }
    }
}

// ネームスペース用 enum（同名関数とViewから呼び分けるため）
private enum Sharing {
    static func editableMapThumbnail(image: UIImage, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Label(L.Share.mapEditHint, systemImage: "pencil")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(10)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
    }
}

// MARK: - 訪問記録共有プレビューシート

struct VisitSharePreviewSheet: View {
    let data: VisitDetailData
    let labelColorMap: [String: Color]
    @Environment(\.dismiss) private var dismiss

    @State private var mapImage: UIImage? = nil
    @State private var renderedShareImage: UIImage? = nil
    @State private var isRendering = false
    @State private var editableText: String = ""
    @State private var showMapEditor = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    textPreviewSection
                    imagePreviewSection
                    if data.coordinate != nil {
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
        .sheet(isPresented: $showMapEditor) {
            if let coord = data.coordinate {
                let region = MKCoordinateRegion(
                    center: coord,
                    latitudinalMeters: 1000,
                    longitudinalMeters: 1000
                )
                ShareMapEditorSheet(visitCoordinate: coord, initialRegion: region) { image in
                    mapImage = image
                }
            }
        }
        .task {
            editableText = VisitDetailDataBuilder.shareText(data: data)
            await generateMapSnapshot()
            await renderShareImage()
        }
    }

    private var textPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L.Share.textLabel, systemImage: "text.quote")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextEditor(text: $editableText)
                .font(.subheadline)
                .frame(minHeight: 80)
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                .scrollContentBackground(.hidden)
        }
        .padding(.horizontal)
    }

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

    @ViewBuilder
    private var mapPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L.Share.mapTitle, systemImage: "map")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if let mapImg = mapImage {
                editableMapThumbnail(image: mapImg)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(24)
            }
        }
    }

    private func buildShareItems() -> [Any] {
        var items: [Any] = [editableText]
        if let img = renderedShareImage { items.append(img) }
        if let map = mapImage { items.append(map) }
        return items
    }

    @MainActor
    private func generateMapSnapshot() async {
        guard let coord = data.coordinate else { return }
        let region = MKCoordinateRegion(center: coord, latitudinalMeters: 1000, longitudinalMeters: 1000)
        mapImage = await makeShareMapSnapshot(region: region, spots: [], orderNumbers: [:], pinCoordinate: coord)
    }

    @MainActor
    private func renderShareImage() async {
        isRendering = true
        defer { isRendering = false }
        let currentLabelColorMap = labelColorMap
        let content = VStack(spacing: 0) {
            VisitDetailContent(
                data: data,
                mapSnapshot: nil,
                isSharing: true,
                nearbyVisits: [],
                nearbyVisitsData: [],
                sameGroupVisits: [],
                sameGroupVisitsData: [],
                currentGroupName: nil,
                labelColorMap: currentLabelColorMap,
                photoFullScreenIndex: .constant(nil)
            )
            .padding(.all, UIConstants.Spacing.xxLarge)
        }
        renderedShareImage = ShareImageRenderer.renderWidth(
            content,
            width: AppConfig.shareImageLogicalWidth,
            scale: AppConfig.shareImageScale
        )
    }
}

extension VisitSharePreviewSheet {
    func editableMapThumbnail(image: UIImage) -> some View {
        Sharing.editableMapThumbnail(image: image) { showMapEditor = true }
    }
}

// MARK: - 地図エディターシート

struct ShareMapEditorSheet: View {
    let spots: [CourseSpot]
    let visitCoordinate: CLLocationCoordinate2D?
    let initialRegion: MKCoordinateRegion
    let onConfirm: (UIImage) -> Void

    @State private var cameraPosition: MapCameraPosition
    @State private var currentRegion: MKCoordinateRegion
    @State private var isCapturing = false
    @Environment(\.dismiss) private var dismiss

    // コース/スポット用
    init(spots: [CourseSpot], initialRegion: MKCoordinateRegion, onConfirm: @escaping (UIImage) -> Void) {
        self.spots = spots
        self.visitCoordinate = nil
        self.initialRegion = initialRegion
        self.onConfirm = onConfirm
        _cameraPosition = State(initialValue: .region(initialRegion))
        _currentRegion = State(initialValue: initialRegion)
    }

    // 訪問記録用
    init(visitCoordinate: CLLocationCoordinate2D, initialRegion: MKCoordinateRegion, onConfirm: @escaping (UIImage) -> Void) {
        self.spots = []
        self.visitCoordinate = visitCoordinate
        self.initialRegion = initialRegion
        self.onConfirm = onConfirm
        _cameraPosition = State(initialValue: .region(initialRegion))
        _currentRegion = State(initialValue: initialRegion)
    }

    var body: some View {
        NavigationStack {
            Map(position: $cameraPosition) {
                ForEach(spots, id: \.id) { spot in
                    if spot.hasValidCoordinate {
                        Annotation(
                            "",
                            coordinate: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude),
                            anchor: .bottom
                        ) {
                            ShareMapPinView()
                        }
                    }
                }
                if let coord = visitCoordinate {
                    Marker("", coordinate: coord)
                        .tint(.blue)
                }
            }
            .mapStyle(.standard(emphasis: .muted))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange(frequency: .onEnd) { ctx in
                currentRegion = ctx.region
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(L.Share.mapEditorTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.Common.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isCapturing {
                        ProgressView().controlSize(.small)
                    } else {
                        Button(L.Common.done) {
                            Task { await captureAndConfirm() }
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private func captureAndConfirm() async {
        isCapturing = true
        let orderMap = Dictionary(uniqueKeysWithValues: spots.enumerated().map { ($0.offset, $0.offset + 1) })
        if let image = await makeShareMapSnapshot(region: currentRegion, spots: spots, orderNumbers: orderMap, pinCoordinate: visitCoordinate) {
            onConfirm(image)
        }
        dismiss()
    }
}

// MARK: - 地図エディター用ピンビュー（近くモードの任意ピンと同デザイン）

private struct ShareMapPinView: View {
    var body: some View {
        Image(systemName: "mappin")
            .font(.system(size: 28))
            .foregroundStyle(.indigo)
            .shadow(radius: 3)
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

// MARK: - 共有地図スナップショット生成（ファイルスコープ）

/// 指定リージョンの地図スナップショットを生成し、SpotPinView スタイルのピンを描画して返す
private func makeShareMapSnapshot(
    region: MKCoordinateRegion,
    spots: [CourseSpot],
    orderNumbers: [Int: Int],
    pinCoordinate: CLLocationCoordinate2D? = nil
) async -> UIImage? {
    let options = MKMapSnapshotter.Options()
    options.region = region
    options.size = CGSize(width: SpotShareCard.cardWidth, height: 200)
    options.scale = UIScreen.main.scale
    options.mapType = .standard
    options.showsBuildings = true
    guard let snapshot = try? await MKMapSnapshotter(options: options).start() else { return nil }
    let size = options.size
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { _ in
        snapshot.image.draw(at: .zero)
        // コーススポットのピン
        for (_, spot) in spots.enumerated() {
            guard spot.hasValidCoordinate else { continue }
            let coord = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
            let point = snapshot.point(for: coord)
            guard point.x >= 0, point.x <= size.width,
                  point.y >= 0, point.y <= size.height else { continue }
            drawSpotPin(at: point)
        }
        // 単一座標ピン（訪問記録共有用：青）
        if let coord = pinCoordinate {
            let point = snapshot.point(for: coord)
            if point.x >= 0, point.x <= size.width,
               point.y >= 0, point.y <= size.height {
                drawSpotPin(at: point, color: .systemBlue)
            }
        }
    }
}

/// 近くモードの任意ピンと同デザインの mappin SF Symbol を描画する
private func drawSpotPin(at point: CGPoint, color: UIColor = .systemIndigo) {
    let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .regular)
    guard let pinImage = UIImage(systemName: "mappin", withConfiguration: config)?
        .withTintColor(color, renderingMode: .alwaysOriginal) else { return }
    let pinSize = pinImage.size
    guard let ctx = UIGraphicsGetCurrentContext() else { return }
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 2), blur: 4,
                  color: UIColor.black.withAlphaComponent(0.35).cgColor)
    // mappin の先端(下端中央)が point に来るよう配置
    pinImage.draw(in: CGRect(
        x: point.x - pinSize.width / 2,
        y: point.y - pinSize.height,
        width: pinSize.width,
        height: pinSize.height
    ))
    ctx.restoreGState()
}

// MARK: - 全スポットを収めるリージョン計算

private func spotsFitRegion(_ spots: [CourseSpot]) -> MKCoordinateRegion {
    let valid = spots.filter { $0.hasValidCoordinate }
    guard !valid.isEmpty else {
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 36.5, longitude: 136.0),
            span: MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 10.0)
        )
    }
    guard valid.count > 1 else {
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: valid[0].latitude, longitude: valid[0].longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
    }
    let lats = valid.map { $0.latitude }
    let lons = valid.map { $0.longitude }
    let centerLat = (lats.min()! + lats.max()!) / 2
    let centerLon = (lons.min()! + lons.max()!) / 2
    let spanLat = max((lats.max()! - lats.min()!) * 1.6, 0.01)
    let spanLon = max((lons.max()! - lons.min()!) * 1.6, 0.01)
    return MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
        span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
    )
}

// MARK: - UIActivityViewController を直接 present するヘルパー

/// SwiftUI の .sheet 経由では二重シート競合が発生するため、UIKit レイヤーで直接 present する
private func presentShareSheet(_ items: [Any]) {
    let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
    vc.excludedActivityTypes = [.assignToContact, .print, .saveToCameraRoll, .addToReadingList]

    guard let scene = UIApplication.shared.connectedScenes
        .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
          let window = scene.windows.first(where: { $0.isKeyWindow }) else { return }

    if let popover = vc.popoverPresentationController {
        popover.sourceView = window
        popover.sourceRect = CGRect(
            x: window.bounds.midX, y: window.bounds.midY,
            width: 0, height: 0
        )
        popover.permittedArrowDirections = []
    }

    var topVC = window.rootViewController
    while let presented = topVC?.presentedViewController {
        topVC = presented
    }
    topVC?.present(vc, animated: true)
}
