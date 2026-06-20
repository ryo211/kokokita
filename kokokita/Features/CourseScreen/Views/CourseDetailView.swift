import SwiftUI
import MapKit
import CoreLocation

/// 地図とリストの表示レイアウトモード
private enum CourseViewLayout: CaseIterable {
    case mapFull   // 地図のみ（リスト非表示）
    case split     // 地図50% / リスト50%
    case listFull  // リストのみ（地図非表示）

    var icon: String {
        switch self {
        case .mapFull:  return "map"
        case .split:    return "rectangle.split.1x2"
        case .listFull: return "list.bullet"
        }
    }
}

enum CourseSpotPhotoSize: String, CaseIterable {
    case none
    case small
    case medium
    case large

    var title: String {
        switch self {
        case .none: return "なし"
        case .small: return "小"
        case .medium: return "中"
        case .large: return "大"
        }
    }
}

// コース詳細画面（地図＋スポット同期リスト）
struct CourseDetailView: View {
    private static let zoomOnSpotFocusKey = "courseDetail.zoomOnSpotFocus"
    private static let spotPhotoSizeKey = "courseDetail.spotPhotoSize"
    // IDを別途保持することでナビゲーション遷移時のキャプチャに依存しない
    private let courseId: UUID
    var showTitle: Bool = true
    private let showSummaryOnAppear: Bool
    @Environment(AppUIState.self) private var appUIState
    @State private var course: Course

    @State private var selectedSpotId: UUID? = nil
    @State private var cameraPosition: MapCameraPosition
    @State private var showSummary = false
    /// 遡り判定結果（この画面を開いたタイミングで表示）
    @State private var pendingRetroactiveResult: RetroactiveResultItem? = nil
    /// コース一覧ストア（遡り判定結果の取得に使用）
    var courseListStore: CourseListStore? = nil
    /// 現在地表示
    @State private var userLocation: CLLocationCoordinate2D? = nil
    @State private var isFetchingLocation = false
    /// 地図とリストの表示レイアウト
    @State private var viewLayout: CourseViewLayout = .split
    /// スポットフォーカス時に地図をズームするか
    @AppStorage(Self.zoomOnSpotFocusKey) private var zoomOnSpotFocus = false
    @AppStorage(Self.spotPhotoSizeKey) private var spotPhotoSizeRaw = CourseSpotPhotoSize.large.rawValue
    @State private var visibleMapSpan = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    /// フォーカス中スポットのスクリーン座標（リーダーライン描画用）
    @State private var selectedSpotScreenPoint: CGPoint? = nil
    /// ライトボックス表示中の画像 URL
    @State private var expandedImageUrl: URL? = nil
    /// ライトボックス表示中の画像クレジット（nil の場合は非表示）
    @State private var expandedImageCredit: String? = nil
    /// 進捗バースワイプの二重発火防止フラグ
    @State private var progressSwipeConsumed = false

    // MARK: - ツアーモード状態
    @AppStorage("tourMode.intervalSeconds") private var tourIntervalSeconds: Double = 3.0
    @AppStorage("tourMode.photoSpotsOnly") private var tourPhotoSpotsOnly = false
    @State private var isTourPlaying = false
    @State private var isTourPaused = false
    @State private var tourSpotIndex = 0
    @State private var tourTask: Task<Void, Never>?
    @State private var showTourSettings = false
    @State private var isShowingTourEndPromotion = false
    // シネマモード（programmatic navigation）
    @State private var showCinemaMode = false
    // タイプライター演出
    @AppStorage("tourMode.typewriterEnabled") private var tourTypewriterEnabled = false
    @State private var typewriterCount: Int = 0
    @State private var typewriterTask: Task<Void, Never>? = nil

    /// ツアーで巡るスポット（写真フィルタを反映）
    private var tourSpots: [CourseSpot] {
        guard tourPhotoSpotsOnly else { return course.spots }
        return course.spots.filter { $0.coverImageUrl != nil || $0.localCoverImagePath != nil }
    }

    /// ツアー中（再生中 or 終了プロモーション表示中）
    private var isTourActive: Bool { isTourPlaying || isShowingTourEndPromotion }

    init(
        course: Course,
        showTitle: Bool = true,
        initialSelectedSpotId: UUID? = nil,
        courseListStore: CourseListStore? = nil,
        showSummaryOnAppear: Bool = false
    ) {
        self.showTitle = showTitle
        self.courseId = course.id
        self.courseListStore = courseListStore
        self.showSummaryOnAppear = showSummaryOnAppear
        _course = State(initialValue: course)
        _selectedSpotId = State(initialValue: initialSelectedSpotId)
        if let spotId = initialSelectedSpotId,
           let spot = course.spots.first(where: { $0.id == spotId }) {
            let radius = spot.recognitionRadiusMeters ?? course.recognitionRadiusMeters
            let span = CourseDetailView.spotSpan(recognitionRadius: radius)
            let savedPhotoSize = CourseSpotPhotoSize(
                rawValue: UserDefaults.standard.string(forKey: Self.spotPhotoSizeKey) ?? CourseSpotPhotoSize.large.rawValue
            ) ?? .large
            let center = CourseDetailView.focusCenter(
                latitude: spot.latitude,
                longitude: spot.longitude,
                span: span,
                photoSize: savedPhotoSize
            )
            _visibleMapSpan = State(initialValue: span)
            _cameraPosition = State(initialValue: .region(
                MKCoordinateRegion(
                    center: center,
                    span: span
                )
            ))
        } else {
            let region = CourseDetailView.fitRegion(for: course.spots)
            _visibleMapSpan = State(initialValue: region.span)
            _cameraPosition = State(initialValue: .region(region))
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                VStack(spacing: 0) {
                    // 地図エリア（mapFull: 全画面 / split: 50% / listFull: 非表示）
                    if viewLayout == .mapFull {
                        mapArea
                    } else if viewLayout == .split {
                        mapArea
                            .frame(height: geo.size.height * 0.50)
                    }

                    // 進捗バー＋レイアウト切替ボタン（ツアーモード中は非表示）
                    if !isTourActive {
                        progressStrip

                        Divider()
                    }

                    // リストエリア（mapFull: 非表示 / split: 50% / listFull: 全画面）
                    if viewLayout != .mapFull {
                        SpotListAreaView(
                            course: course,
                            userLocation: userLocation,
                            selectedSpotId: selectedSpotId,
                            isTourPlaying: isTourActive,
                            typewriterCount: typewriterCount,
                            isTypewriterActive: isTourActive && tourTypewriterEnabled,
                            onSpotTapped: focusSpot,
                            onLayoutSwipe: switchLayout
                        )
                        .equatable()
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: viewLayout)

                // ツアー終了プロモーション画面（タップで解除）
                if isShowingTourEndPromotion {
                    KokokitaEndPromotionStage(
                        safeTop: 0,
                        safeBottom: geo.safeAreaInsets.bottom
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { stopTour() }
                    .transition(.opacity)
                }

            }
            .animation(.easeInOut(duration: 0.4), value: isShowingTourEndPromotion)
        }
        .navigationTitle(showTitle ? course.title : "")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isTourActive)
        .onChange(of: isTourPlaying) { _, playing in
            if playing { appUIState.isTabBarHidden = true }
        }
        .onChange(of: isShowingTourEndPromotion) { _, showing in
            if !showing && !isTourPlaying {
                appUIState.isTabBarHidden = false
            }
        }
        .onDisappear {
            if isTourActive {
                tourTask?.cancel()
                isTourPlaying = false
                isShowingTourEndPromotion = false
                appUIState.isTabBarHidden = false
            }
        }
        .sheet(isPresented: $showTourSettings) {
            SpotTourSettingsSheet(
                intervalSeconds: $tourIntervalSeconds,
                photoSpotsOnly: $tourPhotoSpotsOnly,
                typewriterEnabled: $tourTypewriterEnabled
            ) {
                startTour()
            }
        }
        // 画面表示のたびに最新データを取得（CoreDataキャッシュを確実に反映）
        .task {
            reloadCourse()
            // ハイライトを解除（詳細を開いたことで「新規」状態を消費）
            courseListStore?.newlyAddedCourseIds.remove(courseId)
            if showSummaryOnAppear {
                showSummary = true
            }
            // everEnabled == false のコースは遡り判定未実施 → 直接実行
            if !course.everEnabled {
                await performRetroactiveRecognition()
            }
            // 現在地を初回取得
            await fetchUserLocation(zoomTo: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: .courseChanged)) { _ in
            // チェックイン通知受信時も即時更新
            reloadCourse()
        }
        .onChange(of: spotPhotoSizeRaw) { _, _ in
            guard let spotId = selectedSpotId,
                  let spot = course.spots.first(where: { $0.id == spotId }),
                  spot.hasValidCoordinate else { return }
            let center = focusCenter(for: spot, span: visibleMapSpan)
            withAnimation(.easeInOut(duration: 0.3)) {
                cameraPosition = .region(MKCoordinateRegion(center: center, span: visibleMapSpan))
            }
        }
        .navigationDestination(isPresented: $showCinemaMode) {
            CourseSlideShowView(course: course)
        }
        .toolbar {
            if !isTourActive {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { showSummary = true } label: {
                            Label(L.CourseDetail.menuCourseInfo, systemImage: "info.circle")
                        }

                        Section(L.CourseDetail.menuSectionMapSettings) {
                            Button {
                                zoomOnSpotFocus.toggle()
                            } label: {
                                Label(
                                    zoomOnSpotFocus
                                        ? L.CourseDetail.menuZoomOnFocusOn
                                        : L.CourseDetail.menuZoomOnFocusOff,
                                    systemImage: zoomOnSpotFocus
                                        ? "viewfinder.circle.fill"
                                        : "viewfinder.circle"
                                )
                            }
                            Menu {
                                ForEach(CourseSpotPhotoSize.allCases, id: \.rawValue) { size in
                                    Button {
                                        spotPhotoSizeRaw = size.rawValue
                                    } label: {
                                        if spotPhotoSize == size {
                                            Label(size.title, systemImage: "checkmark")
                                        } else {
                                            Text(size.title)
                                        }
                                    }
                                }
                            } label: {
                                Label(
                                    "\(L.CourseDetail.menuSpotPhotoSize): \(spotPhotoSize.title)",
                                    systemImage: "photo.on.rectangle"
                                )
                            }
                        }

                        Section(L.CourseDetail.menuSectionPlayback) {
                            Button { showTourSettings = true } label: {
                                Label(L.TourMode.menuLabel, systemImage: "scope")
                            }
                            Button { showCinemaMode = true } label: {
                                Label(L.SlideShow.menuLabel, systemImage: "play.rectangle")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showSummary) {
            CourseSummarySheet(course: course)
        }
        // 遡り判定結果シート（ストアシートとの競合を避けるためここに配置）
        .sheet(item: $pendingRetroactiveResult) { result in
            RetroactiveCheckInResultSheet(result: result)
        }
        // スポット画像ライトボックス（タップで閉じる）
        .overlay {
            if let url = expandedImageUrl {
                ZStack {
                    Color.black.opacity(0.65)
                        .ignoresSafeArea()
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image
                                .resizable()
                                .scaledToFit()
                                .padding(32)
                                .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 8)
                        }
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    // 画像クレジット（画像外の右下）
                    if let credit = expandedImageCredit {
                        Text(credit)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.85))
                            .shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .padding(.trailing, 16)
                            .padding(.bottom, 16)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        expandedImageUrl = nil
                        expandedImageCredit = nil
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: expandedImageUrl != nil)
    }

    private var spotPhotoSize: CourseSpotPhotoSize {
        CourseSpotPhotoSize(rawValue: spotPhotoSizeRaw) ?? .large
    }

    private var tourActiveBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "waveform")
                .font(.system(size: 11, weight: .semibold))
                .symbolEffect(.variableColor.iterative, options: .repeating)
            Text("ココキタ")
                .font(.system(size: 13, weight: .bold, design: .rounded))
            Image("kokokita-app-icon-clearBlueDeep")
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background {
            Capsule()
                .fill(Color.indigo)
        }
        .contentShape(Capsule())
    }

    // MARK: - 遡り判定

    /// コース詳細を開いたタイミングで遡り判定を直接実行し、結果をシートで表示する
    private func performRetroactiveRecognition() async {
        let svc = AppContainer.shared.retroactiveService
        let repo = AppContainer.shared.courseRepo
        do {
            // 二重実行防止のため先にフラグをセット
            try repo.setEverEnabled(courseId)
            let result = try svc.recognize(for: courseId)
            guard let r = result, !r.checkedInSpots.isEmpty else { return }
            // コース情報を最新化してからシートを表示
            reloadCourse()
            pendingRetroactiveResult = RetroactiveResultItem(
                course: r.course,
                checkedInSpots: r.checkedInSpots
            )
        } catch {
            Logger.error("遡り判定エラー", error: error)
        }
    }

    // MARK: - 地図エリア

    private var mapArea: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                // 非選択ピンを先に描画（z-order: 下）
                ForEach(Array(course.spots.enumerated()), id: \.element.id) { index, spot in
                    if spot.hasValidCoordinate && spot.id != selectedSpotId {
                        Annotation(
                            "",
                            coordinate: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude),
                            anchor: .center
                        ) {
                            SpotPinView(
                                orderNumber: index + 1,
                                isCheckedIn: spot.isCheckedIn,
                                isSelected: false
                            )
                            .onTapGesture { focusSpot(spot) }
                        }
                    }
                }

                // 選択ピンを最後に単独描画（z-order: 最前面）
                if let selectedId = selectedSpotId,
                   let entry = course.spots.enumerated().first(where: { $0.element.id == selectedId }),
                   entry.element.hasValidCoordinate {
                    let spot = entry.element
                    let coord = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
                    MapCircle(center: coord, radius: spot.recognitionRadiusMeters ?? course.recognitionRadiusMeters)
                        .foregroundStyle(Color.indigo.opacity(0.08))
                        .stroke(Color.indigo.opacity(0.5), lineWidth: 1.5)
                    Annotation("", coordinate: coord, anchor: .center) {
                        SpotPinView(
                            orderNumber: entry.offset + 1,
                            isCheckedIn: spot.isCheckedIn,
                            isSelected: true
                        )
                        .onTapGesture { focusSpot(spot) }
                    }
                }

                // 現在地ピン
                if let coord = userLocation {
                    Annotation("", coordinate: coord, anchor: .center) {
                        ZStack {
                            Circle()
                                .fill(.blue.opacity(0.15))
                                .frame(width: 26, height: 26)
                            Circle()
                                .fill(.blue)
                                .frame(width: 14, height: 14)
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                        }
                    }
                }
            }
            .mapStyle(.standard(emphasis: .muted))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .onChange(of: selectedSpotId) { _, _ in
                // スポット変更（選択・解除問わず）は即座に非表示
                // → カメラ停止後に onEnd で座標を確定して再表示
                selectedSpotScreenPoint = nil
            }
            .task(id: selectedSpotId) {
                guard selectedSpotId != nil else { return }
                // Programmatic camera moves do not always emit onEnd, so retry after layout/camera settle.
                try? await Task.sleep(nanoseconds: 180_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        updateSpotScreenPoint(proxy: proxy)
                    }
                }
                try? await Task.sleep(nanoseconds: 320_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if selectedSpotScreenPoint == nil {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            updateSpotScreenPoint(proxy: proxy)
                        }
                    }
                }
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                visibleMapSpan = context.region.span
                // カメラ停止後にスポット座標を確定してフェードイン表示
                withAnimation(.easeInOut(duration: 0.2)) {
                    updateSpotScreenPoint(proxy: proxy)
                }
            }
            .onMapCameraChange(frequency: .continuous) { context in
                visibleMapSpan = context.region.span
                // 画像が表示済みの場合のみリアルタイム追従（手動パン中）
                guard selectedSpotScreenPoint != nil else { return }
                updateSpotScreenPoint(proxy: proxy)
            }
            .overlay {
                leaderLineOverlay
            }
            .overlay(alignment: .bottomTrailing) {
                if isTourActive {
                    HStack(spacing: 10) {
                        Button {
                            isTourPaused ? resumeTour() : pauseTour()
                        } label: {
                            Image(systemName: isTourPaused ? "play.fill" : "pause.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(Color.indigo, in: Circle())
                        }
                        .buttonStyle(.plain)

                        tourActiveBadge
                            .onTapGesture { stopTour() }
                    }
                    .padding([.trailing, .bottom], 16)
                } else {
                    locationButton
                        .padding([.trailing, .bottom], 12)
                }
            }
        }
    }

    /// フォーカス中スポットのスクリーン座標を MapProxy で更新する
    private func updateSpotScreenPoint(proxy: MapProxy) {
        guard let spotId = selectedSpotId,
              let spot = course.spots.first(where: { $0.id == spotId }),
              spot.hasValidCoordinate else {
            selectedSpotScreenPoint = nil
            return
        }
        let coord = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
        selectedSpotScreenPoint = proxy.convert(coord, to: .local)
    }

    /// フォーカス中スポットに画像がある場合、スポット位置からリーダーライン付きで表示
    @ViewBuilder
    private var leaderLineOverlay: some View {
        if spotPhotoSize != .none,
           let spotPoint = selectedSpotScreenPoint,
           let spot = course.spots.first(where: { $0.id == selectedSpotId }) {
            // ローカル保存画像 → リモートURL の順で優先
            let localImage = spot.localCoverImagePath.flatMap { LocalImageStorage.shared.load(from: $0) }
            let remoteUrl = spot.coverImageUrl.flatMap { URL(string: $0) }

            if localImage != nil || remoteUrl != nil {
                SpotLeaderLineView(
                    spotPoint: spotPoint,
                    size: spotPhotoSize,
                    localImage: localImage,
                    imageUrl: remoteUrl
                ) {
                    if let url = remoteUrl {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedImageUrl = url
                            expandedImageCredit = spot.imageCredit.flatMap { $0.isEmpty ? nil : $0 }
                        }
                    }
                }
                .transition(.opacity)
            }
        }
    }

    // MARK: - 進捗ストリップ＋レイアウト切替（地図とリストの間に固定表示）

    private var progressStrip: some View {
        HStack(spacing: 8) {
            if course.isCompleted {
                Label(L.Course.completed, systemImage: "checkmark.seal.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.indigo)
            } else {
                Text(L.Course.spotProgress(course.checkedInCount, course.totalSpotCount))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(course.checkedInCount), total: Double(course.totalSpotCount))
                    .tint(.indigo)
            }
            Spacer()
            // レイアウト切替ボタン
            HStack(spacing: 2) {
                ForEach(CourseViewLayout.allCases, id: \.self) { layout in
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewLayout = layout
                        }
                    } label: {
                        Image(systemName: layout.icon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(viewLayout == layout ? Color.indigo : Color.secondary)
                            .frame(width: 28, height: 28)
                            .background(
                                viewLayout == layout
                                    ? Color.indigo.opacity(0.12)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        // 上下スワイプでレイアウト切替（仕切りをドラッグする感覚）
        // 上スワイプ → リスト拡大方向 / 下スワイプ → 地図拡大方向
        .gesture(
            DragGesture(minimumDistance: 5, coordinateSpace: .local)
                .onChanged { value in
                    guard !progressSwipeConsumed else { return }
                    if value.translation.height < -15 {
                        progressSwipeConsumed = true
                        switchLayout(true)
                    } else if value.translation.height > 15 {
                        progressSwipeConsumed = true
                        switchLayout(false)
                    }
                }
                .onEnded { _ in progressSwipeConsumed = false }
        )
    }

    // MARK: - レイアウト切替ヘルパー

    /// isUp=true: リスト拡大方向 / isUp=false: 地図拡大方向
    private func switchLayout(_ isUp: Bool) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if isUp {
                switch viewLayout {
                case .mapFull:  viewLayout = .split
                case .split:    viewLayout = .listFull
                case .listFull: break
                }
            } else {
                switch viewLayout {
                case .mapFull:  break
                case .split:    viewLayout = .mapFull
                case .listFull: viewLayout = .split
                }
            }
        }
    }

    // MARK: - 現在地ボタン（地図右下）

    private var locationButton: some View {
        Button {
            Task { await fetchUserLocation(zoomTo: true) }
        } label: {
            ZStack {
                Circle()
                    .fill(.regularMaterial)
                    .frame(width: 36, height: 36)
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                if isFetchingLocation {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: userLocation != nil ? "location.fill" : "location")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(userLocation != nil ? Color.blue : Color.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - データ再取得

    private func reloadCourse() {
        if let updated = try? AppContainer.shared.courseRepo.fetch(id: courseId) {
            course = updated
        }
    }

    // MARK: - 現在地取得

    @MainActor
    private func fetchUserLocation(zoomTo: Bool) async {
        guard !isFetchingLocation else { return }
        isFetchingLocation = true
        defer { isFetchingLocation = false }
        do {
            let service = DefaultLocationService()
            let (location, _) = try await service.requestOneShotLocation(
                accuracy: kCLLocationAccuracyHundredMeters,
                timeout: 8.0
            )
            userLocation = location.coordinate
            if zoomTo {
                withAnimation(.easeInOut(duration: 0.5)) {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                    ))
                }
            }
        } catch {
            Logger.warning("現在地取得失敗: \(error)")
        }
    }

    // MARK: - フォーカス同期

    private func focusSpot(_ spot: CourseSpot) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if selectedSpotId == spot.id {
                // 同じスポット再タップ → 選択解除＋全スポット表示
                selectedSpotId = nil
                cameraPosition = .region(CourseDetailView.fitRegion(for: course.spots))
            } else {
                selectedSpotId = spot.id
                // 不正な座標の場合は選択状態だけ更新してカメラ移動はしない
                guard spot.hasValidCoordinate else { return }
                let radius = spot.recognitionRadiusMeters ?? course.recognitionRadiusMeters
                let span = zoomOnSpotFocus
                    ? CourseDetailView.spotSpan(recognitionRadius: radius)
                    : visibleMapSpan
                let center = focusCenter(for: spot, span: span)
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: center,
                        span: span
                    )
                )
            }
        }
    }

    private func focusCenter(for spot: CourseSpot, span: MKCoordinateSpan) -> CLLocationCoordinate2D {
        CourseDetailView.focusCenter(
            latitude: spot.latitude,
            longitude: spot.longitude,
            span: span,
            photoSize: spotPhotoSize
        )
    }

    // MARK: - スポット巡りモード

    private func startTour() {
        let spots = tourSpots
        guard !spots.isEmpty else { return }
        // 地図が見えていないレイアウトの場合は split に切り替え
        if viewLayout == .listFull {
            withAnimation(.easeInOut(duration: 0.3)) { viewLayout = .split }
        }
        isTourPlaying = true
        isTourPaused = false
        isShowingTourEndPromotion = false
        tourSpotIndex = 0
        tourFocusSpot(spots[0])
        scheduleOrTypewriter(for: spots[0])
    }

    private func stopTour() {
        tourTask?.cancel()
        typewriterTask?.cancel()
        typewriterCount = 0
        isTourPlaying = false
        isTourPaused = false
        isShowingTourEndPromotion = false
        appUIState.isTabBarHidden = false
    }

    private func pauseTour() {
        isTourPaused = true
        tourTask?.cancel()
        typewriterTask?.cancel()
    }

    private func resumeTour() {
        isTourPaused = false
        let spots = tourSpots
        guard tourSpotIndex < spots.count else { return }
        scheduleOrTypewriter(for: spots[tourSpotIndex])
    }

    private func scheduleTourAdvance() {
        tourTask?.cancel()
        tourTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(tourIntervalSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run { advanceTour() }
        }
    }

    /// タイプライターON → タイプライター演出、OFF → タイマー自動進行
    private func scheduleOrTypewriter(for spot: CourseSpot) {
        if tourTypewriterEnabled {
            startTypewriter(for: spot)
        } else {
            scheduleTourAdvance()
        }
    }

    /// タイトル → 説明文の順に1文字ずつ太字化し、完了後に余韻を残してから次のスポットへ進む
    private func startTypewriter(for spot: CourseSpot) {
        typewriterTask?.cancel()
        typewriterCount = 0
        let totalChars = spot.name.count + (spot.spotDescription?.count ?? 0)
        guard totalChars > 0 else { scheduleTourAdvance(); return }
        typewriterTask = Task {
            for _ in 0..<totalChars {
                try? await Task.sleep(nanoseconds: 20_000_000) // 40ms/文字
                guard !Task.isCancelled else { return }
                await MainActor.run { typewriterCount += 1 }
            }
            // 全文字太字化後、余韻として1秒待ってから次のスポットへ
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { advanceTour() }
        }
    }

    private func advanceTour() {
        let spots = tourSpots
        let nextIndex = tourSpotIndex + 1
        if nextIndex < spots.count {
            tourSpotIndex = nextIndex
            tourFocusSpot(spots[nextIndex])
            scheduleOrTypewriter(for: spots[nextIndex])
        } else {
            // 全スポット終了 → プロモーション画面へ
            tourTask?.cancel()
            isTourPlaying = false
            withAnimation(.easeInOut(duration: 0.5)) {
                isShowingTourEndPromotion = true
            }
        }
    }

    private func tourFocusSpot(_ spot: CourseSpot) {
        withAnimation(.easeInOut(duration: 0.6)) {
            selectedSpotId = spot.id
            guard spot.hasValidCoordinate else { return }
            // ズームは変えずに現在のスパンのままスポットを中心に移動
            let center = focusCenter(for: spot, span: visibleMapSpan)
            cameraPosition = .region(MKCoordinateRegion(center: center, span: visibleMapSpan))
        }
    }

    // MARK: - 全スポットフィット計算

    /// recognitionRadiusMeters の円が地図上に収まるズームスパンを返す。
    /// 緯度1度≈111,000m を基準に変換し、直径の2.5倍のパディングを追加。
    /// 最小 0.002°（約220m）、最大 0.3°（約33km）にクランプ。
    static func spotSpan(recognitionRadius: Double) -> MKCoordinateSpan {
        let diameterDegrees = (recognitionRadius * 2) / 111_000.0
        let delta = max(0.002, min(diameterDegrees * 2.5, 0.3))
        return MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)
    }

    private static func focusCenter(
        latitude: Double,
        longitude: Double,
        span: MKCoordinateSpan,
        photoSize: CourseSpotPhotoSize
    ) -> CLLocationCoordinate2D {
        guard photoSize == .large else {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }

        // Large photos occupy the upper half, so place the focused spot around the lower-half center.
        return CLLocationCoordinate2D(
            latitude: min(90, latitude + span.latitudeDelta * 0.25),
            longitude: longitude
        )
    }

    static func fitRegion(for spots: [CourseSpot]) -> MKCoordinateRegion {
        let spots = spots.filter { $0.hasValidCoordinate }
        guard !spots.isEmpty else {
            // 0件 → 日本中心（span 10°）
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 36.5, longitude: 136.0),
                span: MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 10.0)
            )
        }

        guard spots.count > 1 else {
            // 1件 → span 0.02°
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: spots[0].latitude, longitude: spots[0].longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        }

        // 複数件 → バウンディングボックス * 1.5、最小 0.01°
        let lats = spots.map { $0.latitude }
        let lons = spots.map { $0.longitude }
        let minLat = lats.min()!
        let maxLat = lats.max()!
        let minLon = lons.min()!
        let maxLon = lons.max()!

        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let spanLat = max((maxLat - minLat) * 1.5, 0.01)
        let spanLon = max((maxLon - minLon) * 1.5, 0.01)

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
        )
    }
}

// MARK: - スポット巡りモード設定シート

struct SpotTourSettingsSheet: View {
    @Binding var intervalSeconds: Double
    @Binding var photoSpotsOnly: Bool
    @Binding var typewriterEnabled: Bool
    @Environment(\.dismiss) private var dismiss
    let onStart: () -> Void

    private var clampedInterval: Double {
        min(max(0.5, intervalSeconds), 5.0)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                // スポット表示時間（タイプライターON時は無効）
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L.TourMode.settingsIntervalLabel)
                            .font(.headline)
                        Spacer()
                        Text(L.TourMode.settingsIntervalSec(clampedInterval))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $intervalSeconds, in: 0.5...5, step: 0.5)
                        .tint(.indigo)

                    HStack {
                        Text(L.TourMode.settingsIntervalMin)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(L.TourMode.settingsIntervalMax)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(typewriterEnabled)
                .opacity(typewriterEnabled ? 0.35 : 1)

                Toggle(L.TourMode.settingsPhotoSpotsOnly, isOn: $photoSpotsOnly)
                    .font(.headline)
                    .tint(.indigo)

                // タイプライター演出
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(L.TourMode.settingsTypewriter, isOn: $typewriterEnabled)
                        .font(.headline)
                        .tint(.indigo)
                    Text(L.TourMode.settingsTypewriterDesc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    dismiss()
                    onStart()
                } label: {
                    Label(L.TourMode.startButton, systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.indigo, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(.white)
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle(L.TourMode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L.Common.cancel) { dismiss() }
                }
            }
        }
        .presentationDetents([.height(440)])
    }
}


// MARK: - スポットリストエリア

/// course・selectedSpotId・userLocation が変化しない限り再レンダリングをスキップする。
/// ドラッグ中は mapDragDelta しか変わらないため、リスト側の評価コストをゼロにできる。
private struct SpotListAreaView: View, Equatable {
    let course: Course
    let userLocation: CLLocationCoordinate2D?
    let selectedSpotId: UUID?
    /// ツアー再生中は達成済スポットを非表示にしてソートチップも隠す
    var isTourPlaying: Bool = false
    /// タイプライター演出で太字化済みの文字数（タイトル + 説明文を合算）
    var typewriterCount: Int = 0
    /// タイプライター演出が有効かどうか
    var isTypewriterActive: Bool = false
    let onSpotTapped: (CourseSpot) -> Void
    /// 上スワイプ=true / 下スワイプ=false でレイアウト切替を親に通知
    var onLayoutSwipe: (Bool) -> Void = { _ in }

    @State private var sortByDistance = false
    @State private var sortHeaderSwipeConsumed = false

    /// closureは比較対象外。データの変化のみで再レンダリング判定する
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.course == rhs.course &&
        lhs.selectedSpotId == rhs.selectedSpotId &&
        lhs.isTourPlaying == rhs.isTourPlaying &&
        lhs.typewriterCount == rhs.typewriterCount &&
        lhs.isTypewriterActive == rhs.isTypewriterActive &&
        lhs.userLocation?.latitude == rhs.userLocation?.latitude &&
        lhs.userLocation?.longitude == rhs.userLocation?.longitude
    }

    /// グローバルスポット番号（全セクション横断、地図ピンと対応）
    private var globalSpotIndex: [UUID: Int] {
        Dictionary(uniqueKeysWithValues: course.spots.enumerated().map { ($1.id, $0) })
    }

    /// 距離順にソートしたスポット一覧
    private var distanceSortedSpots: [(spot: CourseSpot, distance: Double?)] {
        course.spots.map { spot in
            let distance: Double? = userLocation.map { loc in
                CLLocation(latitude: loc.latitude, longitude: loc.longitude)
                    .distance(from: CLLocation(latitude: spot.latitude, longitude: spot.longitude))
            }
            return (spot, distance)
        }
        .sorted { ($0.distance ?? .infinity) < ($1.distance ?? .infinity) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ソートヘッダー（ツアー中は非表示）
            if !isTourPlaying {
                HStack(spacing: 8) {
                    SortChip(label: L.Course.sortDefault, isSelected: !sortByDistance) {
                        sortByDistance = false
                    }
                    SortChip(label: L.Course.sortDistance, isSelected: sortByDistance) {
                        sortByDistance = true
                    }
                    .disabled(userLocation == nil)
                    .opacity(userLocation == nil ? 0.4 : 1)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 5, coordinateSpace: .local)
                        .onChanged { value in
                            guard !sortHeaderSwipeConsumed else { return }
                            if value.translation.height < -15 {
                                sortHeaderSwipeConsumed = true
                                onLayoutSwipe(true)
                            } else if value.translation.height > 15 {
                                sortHeaderSwipeConsumed = true
                                onLayoutSwipe(false)
                            }
                        }
                        .onEnded { _ in sortHeaderSwipeConsumed = false }
                )

                Divider()
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        let indexMap = globalSpotIndex
                        if sortByDistance && !isTourPlaying {
                            // 距離順フラットリスト（セクション無視）
                            let sorted = distanceSortedSpots
                            ForEach(sorted, id: \.spot.id) { item in
                                SpotListRowView(
                                    spot: item.spot,
                                    orderNumber: (indexMap[item.spot.id] ?? 0) + 1,
                                    isSelected: selectedSpotId == item.spot.id,
                                    distance: item.distance,
                                    tourTypewriterCount: (isTypewriterActive && selectedSpotId == item.spot.id) ? typewriterCount : nil
                                )
                                .id(item.spot.id)
                                .onTapGesture { onSpotTapped(item.spot) }

                                if item.spot.id != sorted.last?.spot.id {
                                    Divider().padding(.leading, 52)
                                }
                            }
                        } else {
                            // デフォルト: セクション別（ツアー中は達成済スポットを非表示）
                            ForEach(course.sections) { section in
                                let visibleSpots = isTourPlaying
                                    ? section.spots.filter { !$0.isCheckedIn }
                                    : section.spots
                                if !visibleSpots.isEmpty {
                                    if section.hasName {
                                        CourseSectionHeaderView(section: section)
                                    }
                                    ForEach(visibleSpots) { spot in
                                        let distance: Double? = userLocation.map { loc in
                                            CLLocation(latitude: loc.latitude, longitude: loc.longitude)
                                                .distance(from: CLLocation(latitude: spot.latitude, longitude: spot.longitude))
                                        }
                                        SpotListRowView(
                                            spot: spot,
                                            orderNumber: (indexMap[spot.id] ?? 0) + 1,
                                            isSelected: selectedSpotId == spot.id,
                                            distance: distance,
                                            tourTypewriterCount: (isTypewriterActive && selectedSpotId == spot.id) ? typewriterCount : nil
                                        )
                                        .id(spot.id)
                                        .onTapGesture { onSpotTapped(spot) }

                                        if spot.id != visibleSpots.last?.id {
                                            Divider().padding(.leading, 52)
                                        }
                                    }
                                    if section.id != course.sections.last?.id {
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                }
                .onChange(of: selectedSpotId) { _, newId in
                    if let id = newId {
                        withAnimation { proxy.scrollTo(id, anchor: .top) }
                    }
                }
                .task {
                    guard let id = selectedSpotId else { return }
                    try? await Task.sleep(nanoseconds: 150_000_000)
                    withAnimation { proxy.scrollTo(id, anchor: .top) }
                }
            }
        }
    }
}

// MARK: - ソートチップ

private struct SortChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Color.indigo : Color.secondary.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - セクションヘッダー

private struct CourseSectionHeaderView: View {
    let section: CourseSection

    var body: some View {
        HStack {
            Text(section.name)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemBackground))
    }
}

// MARK: - 地図ピンビュー

private struct SpotPinView: View {
    let orderNumber: Int
    let isCheckedIn: Bool
    let isSelected: Bool

    private var size: CGFloat { isSelected ? 20 : 14 }

    var body: some View {
        ZStack {
            // フォーカス時のスポットライト（背後からの照射グロー）
            Circle()
                .fill(Color.indigo.opacity(0.38))
                .frame(width: 42, height: 42)
                .blur(radius: 9)
                .scaleEffect(isSelected ? 1 : 0.01)
                .opacity(isSelected ? 1 : 0)

            // 外縁（白リング + 影）
            Circle()
                .fill(Color.white)
                .frame(width: size + 5, height: size + 5)
                .shadow(color: .black.opacity(isSelected ? 0.4 : 0.25),
                        radius: isSelected ? 6 : 3, x: 0, y: 2)

            if isCheckedIn {
                // 達成済み：ゴールド + スター
                Circle()
                    .fill(Color(hue: 0.13, saturation: 0.85, brightness: 0.95))
                    .frame(width: size, height: size)
                Image(systemName: "star.fill")
                    .font(.system(size: isSelected ? 9 : 6, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                // 未達成：インディゴ + 番号
                Circle()
                    .fill(Color.indigo)
                    .frame(width: size, height: size)
                Text("\(orderNumber)")
                    .font(.system(size: isSelected ? 9 : 6, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .animation(.easeOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - スポットリスト行

private struct SpotListRowView: View {
    let spot: CourseSpot
    let orderNumber: Int
    let isSelected: Bool
    var distance: Double? = nil
    /// タイプライター演出で太字化済みの文字数（nil = 演出なし）
    var tourTypewriterCount: Int? = nil

    @Environment(\.spotFavoriteStore) private var favoriteStore

    private var distanceText: String? {
        guard let d = distance else { return nil }
        return d < 1000 ? String(format: "%.0fm", d) : String(format: "%.1fkm", d / 1000)
    }

    /// 全文を表示しつつ前から boldCount 文字を太字・primaryカラーにした AttributedString を返す
    private func makeTypewriterAttributedText(full: String, boldCount: Int, boldFont: Font, dimFont: Font) -> AttributedString {
        var result = AttributedString(full)
        let clampedCount = min(boldCount, full.count)
        let boldEnd = result.index(result.startIndex, offsetByCharacters: clampedCount)

        if result.startIndex < boldEnd {
            result[result.startIndex..<boldEnd].font = boldFont
            result[result.startIndex..<boldEnd].foregroundColor = Color.primary
        }
        if boldEnd < result.endIndex {
            result[boldEnd..<result.endIndex].font = dimFont
            result[boldEnd..<result.endIndex].foregroundColor = Color.secondary
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // メイン行
            HStack(spacing: 12) {
                // 番号バッジ（達成済み: ゴールド★ / 未達成: インディゴ番号）
                ZStack {
                    Circle()
                        .fill(spot.isCheckedIn
                              ? Color(hue: 0.13, saturation: 0.85, brightness: 0.95)
                              : Color.indigo)
                        .frame(width: 32, height: 32)
                    if spot.isCheckedIn {
                        Image(systemName: "star.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Text("\(orderNumber)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        if let count = tourTypewriterCount {
                            // タイプライター演出中: タイトルも薄い → 太字へ
                            Text(makeTypewriterAttributedText(
                                full: spot.name,
                                boldCount: count,
                                boldFont: .body.bold(),
                                dimFont: .body
                            ))
                        } else {
                            Text(spot.name)
                                .font(.body)
                        }

                        if spot.isCheckedIn {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.body)
                                .foregroundStyle(Color.indigo)
                        }
                    }

                    if let count = tourTypewriterCount, let desc = spot.spotDescription {
                        // タイプライター演出中: 説明文は title.count 分を差し引いた残りでboldCount計算
                        let descBoldCount = max(0, count - spot.name.count)
                        Text(makeTypewriterAttributedText(
                            full: desc,
                            boldCount: descBoldCount,
                            boldFont: .caption.bold(),
                            dimFont: .caption
                        ))
                        .lineLimit(nil)
                    } else if let desc = spot.spotDescription {
                        Text(desc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            // フォーカス時は全表示、非フォーカス時は最大2行
                            .lineLimit(isSelected ? nil : 2)
                    }

                    // 現在地からの距離（スポット説明の下）
                    if let text = distanceText {
                        HStack(spacing: 2) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                            Text(text)
                                .font(.caption2.bold().monospacedDigit())
                        }
                        .foregroundStyle(.indigo)
                        .padding(.top, 1)
                    }
                }

                Spacer()

                // ハートボタン（お気に入り）
                Button {
                    favoriteStore.toggle(spot.id)
                } label: {
                    Image(systemName: favoriteStore.isFavorite(spot.id) ? "heart.fill" : "heart")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(
                            favoriteStore.isFavorite(spot.id)
                                ? Color(red: 1.0, green: 0.42, blue: 0.62)
                                : Color.secondary.opacity(0.88)
                        )
                        .shadow(color: Color(uiColor: .systemBackground).opacity(0.9), radius: 1.5, x: 0, y: 0)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // 展開詳細（選択時のみ）
            if isSelected {
                SpotDetailExpandedView(spot: spot)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background {
            SpotRowBackdropView(spot: spot, isSelected: isSelected)
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

private struct SpotRowBackdropView: View {
    let spot: CourseSpot
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var hasImage: Bool {
        spot.localCoverImagePath != nil || spot.coverImageUrl != nil
    }

    private var imageOpacity: Double {
        if colorScheme == .dark {
            return isSelected ? 0.82 : 0.72
        }
        return isSelected ? 0.62 : 0.50
    }

    private var trailingBackgroundOpacity: Double {
        colorScheme == .dark ? 0.02 : 0.10
    }

    private var midBackgroundOpacity: Double {
        colorScheme == .dark ? 0.42 : 0.62
    }

    private var selectedTintOpacity: Double {
        colorScheme == .dark ? 0.11 : 0.07
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .trailing) {
                if hasImage {
                    SpotRowBackdropImageView(spot: spot)
                        .frame(
                            width: max(geo.size.width * (isSelected ? 0.6 : 0.55), 188),
                            height: geo.size.height
                        )
                        .clipped()
                        .opacity(imageOpacity)
                        .saturation(colorScheme == .dark ? (isSelected ? 1.16 : 1.1) : (isSelected ? 1.1 : 1.05))
                        .contrast(colorScheme == .dark ? 1.05 : 1.12)
                        .offset(x: 10)
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .white.opacity(0.18), location: 0.12),
                                    .init(color: .white.opacity(0.50), location: 0.36),
                                    .init(color: .white, location: 0.76)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    LinearGradient(
                        colors: [
                            Color(uiColor: .systemBackground),
                            Color(uiColor: .systemBackground).opacity(midBackgroundOpacity),
                            Color(uiColor: .systemBackground).opacity(trailingBackgroundOpacity)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }

                if spot.isCheckedIn {
                    Image("kokokita_hanko")
                        .resizable()
                        .scaledToFit()
                        .frame(width: min(geo.size.width * 0.42, 172))
                        .opacity(isSelected ? 0.48 : 0.40)
                        .rotationEffect(.degrees(-10))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                        .offset(x: -8, y: isSelected ? 6 : 2)
                }

                if isSelected {
                    Color.indigo.opacity(selectedTintOpacity)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .allowsHitTesting(false)
    }
}

private struct SpotRowBackdropImageView: View {
    let spot: CourseSpot

    var body: some View {
        Group {
            if let uiImage = spot.localCoverImagePath.flatMap({ LocalImageStorage.shared.load(from: $0) }) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let urlStr = spot.coverImageUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Color.clear
                    }
                }
            } else {
                Color.clear
            }
        }
    }
}

// MARK: - スポット詳細展開ビュー

private struct SpotDetailExpandedView: View {
    let spot: CourseSpot
    @State private var linkedVisits: [VisitAggregate] = []
    @State private var labelMap: [UUID: String] = [:]
    @State private var groupMap: [UUID: String] = [:]
    @State private var memberMap: [UUID: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 住所・訪問日（アイコン幅を固定してインデントを揃える）
            let iconWidth: CGFloat = 14
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "mappin.circle")
                    .font(.caption)
                    .frame(width: iconWidth)
                Text(spot.address ?? L.Course.noAddress)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(spot.address != nil ? Color.secondary : Color.secondary.opacity(0.5))
            .padding(.leading, 60)
            .padding(.trailing, 16)

            if let date = spot.firstCheckedInAt {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "calendar.circle")
                        .font(.caption)
                        .frame(width: iconWidth)
                    Text(L.Course.visitedOn(date.formatted(date: .long, time: .omitted)))
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Color.indigo)
                .padding(.leading, 60)
                .padding(.trailing, 16)
            } else {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "calendar.circle")
                        .font(.caption)
                        .frame(width: iconWidth)
                    Text(L.Course.notVisited)
                        .font(.caption)
                }
                .foregroundStyle(Color.secondary)
                .padding(.leading, 60)
                .padding(.trailing, 16)
            }

            // 紐づいた記録カード横スクロール（紐づきがある場合のみ）
            if !linkedVisits.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(linkedVisits, id: \.visit.id) { aggregate in
                            NavigationLink {
                                VisitDetailScreen(
                                    data: toDetailData(aggregate),
                                    visitId: aggregate.id,
                                    onBack: {},
                                    onEdit: {},
                                    onShare: {},
                                    onDelete: {
                                        try? AppContainer.shared.repo.delete(id: aggregate.id)
                                        NotificationCenter.default.post(name: .visitsChanged, object: nil)
                                        reloadLinkedVisits()
                                    },
                                    onUpdate: {
                                        NotificationCenter.default.post(name: .visitsChanged, object: nil)
                                        reloadLinkedVisits()
                                    },
                                    onMapTap: nil
                                )
                            } label: {
                                CheckInVisitCard(aggregate: aggregate)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.leading, 60)
                    .padding(.trailing, 16)
                    .padding(.bottom, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 10)
        .task(id: spot.id) {
            await loadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .visitsChanged)) { _ in
            reloadLinkedVisits()
        }
    }

    // MARK: - データ読み込み

    private func loadData() async {
        let repo = AppContainer.shared.repo
        labelMap = (try? repo.allLabels())?.reduce(into: [:]) { $0[$1.id] = $1.name } ?? [:]
        groupMap = (try? repo.allGroups())?.reduce(into: [:]) { $0[$1.id] = $1.name } ?? [:]
        memberMap = (try? repo.allMembers())?.reduce(into: [:]) { $0[$1.id] = $1.name } ?? [:]
        reloadLinkedVisits()
    }

    private func reloadLinkedVisits() {
        guard !spot.visitIds.isEmpty else {
            linkedVisits = []
            return
        }
        linkedVisits = spot.visitIds.compactMap { id in
            try? AppContainer.shared.repo.get(by: id)
        }
    }

    // MARK: - VisitDetailData 構築

    private func toDetailData(_ agg: VisitAggregate) -> VisitDetailData {
        let title: String = {
            let t = agg.details.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let t, !t.isEmpty { return t }
            if let f = agg.details.facilityName, !f.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return f }
            return L.Home.noTitle
        }()

        let coord: CLLocationCoordinate2D? = {
            let lat = agg.visit.latitude
            let lon = agg.visit.longitude
            guard lat != 0 || lon != 0 else { return nil }
            return .init(latitude: lat, longitude: lon)
        }()

        return VisitDetailData(
            title: title,
            labels: agg.details.labelIds.compactMap { labelMap[$0] },
            group: agg.details.groupId.flatMap { groupMap[$0] },
            members: agg.details.memberIds.compactMap { memberMap[$0] },
            timestamp: agg.visit.timestampUTC,
            address: agg.details.resolvedAddress ?? agg.details.facilityAddress,
            coordinate: coord,
            memo: agg.details.comment,
            facility: FacilityInfo(
                name: agg.details.facilityName,
                address: agg.details.facilityAddress,
                phone: nil
            ),
            facilityCategory: agg.details.facilityCategory,
            photoPaths: agg.details.photoPaths,
            isManualEntry: agg.visit.isManualEntry
        )
    }
}

// MARK: - スポット画像リーダーラインビュー

/// スポットのスクリーン座標から右上方向にリーダーライン（指示棒）を伸ばし、画像を表示する
struct SpotLeaderLineView: View {
    let spotPoint: CGPoint
    let size: CourseSpotPhotoSize
    /// ローカル保存画像（優先）
    var localImage: UIImage? = nil
    /// リモート画像URL（ローカルがない場合にフォールバック）
    var imageUrl: URL? = nil
    var onImageTap: () -> Void = {}

    /// 地図端からのマージン
    private let margin: CGFloat = 12

    var body: some View {
        GeometryReader { geo in
            let imageSize = imageSize(in: geo.size)
            let imgCenter = imageCenter(in: geo.size, imageSize: imageSize)
            let lineEnd = lineEnd(imageCenter: imgCenter, imageSize: imageSize)

            ZStack {
                // リーダーライン（ピン外縁 → 画像端）
                Canvas { ctx, _ in
                    // ピン外縁半径分オフセット（番号が見えるようピンの裏から線を出す）
                    let pinOuterRadius: CGFloat = 13
                    let dx = lineEnd.x - spotPoint.x
                    let dy = lineEnd.y - spotPoint.y
                    let dist = sqrt(dx * dx + dy * dy)
                    let lineStart: CGPoint = dist > 0
                        ? CGPoint(x: spotPoint.x + dx / dist * pinOuterRadius,
                                  y: spotPoint.y + dy / dist * pinOuterRadius)
                        : spotPoint

                    let path: Path = {
                        var p = Path()
                        p.move(to: lineStart)
                        p.addLine(to: lineEnd)
                        return p
                    }()
                    // シャドウ（可読性確保）
                    ctx.stroke(path, with: .color(.black.opacity(0.25)),
                               style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                    // 本体（白い線）
                    ctx.stroke(path, with: .color(.white.opacity(0.95)),
                               style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                }
                .allowsHitTesting(false)

                // スポット画像（ローカル優先、なければリモートURL）
                Group {
                    if let uiImage = localImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: imageSize.width, height: imageSize.height)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 2)
                    } else if let url = imageUrl {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: imageSize.width, height: imageSize.height)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 2)
                            case .empty:
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(.regularMaterial)
                                    .frame(width: imageSize.width, height: imageSize.height)
                                    .overlay(ProgressView().controlSize(.small))
                                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
                            case .failure:
                                EmptyView()
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                }
                .position(imgCenter)
                .onTapGesture { onImageTap() }
            }
            // 地図エリア外への描画を防ぐ
            .clipped()
        }
    }

    private func imageSize(in containerSize: CGSize) -> CGSize {
        switch size {
        case .none:
            return .zero
        case .small:
            return CGSize(width: 66, height: 44)
        case .medium:
            return CGSize(width: 132, height: 88)
        case .large:
            let height = max(120, containerSize.height * 0.45)
            let maxWidth = max(containerSize.width - 32, 0)
            let minWidth = min(180, maxWidth)
            let width = min(maxWidth, max(height * 1.62, minWidth))
            return CGSize(width: width, height: height)
        }
    }

    private func imageCenter(in containerSize: CGSize, imageSize: CGSize) -> CGPoint {
        switch size {
        case .large:
            return CGPoint(x: containerSize.width / 2, y: imageSize.height / 2 + margin)
        case .none, .small, .medium:
            return CGPoint(
                x: containerSize.width - imageSize.width / 2 - margin,
                y: imageSize.height / 2 + margin
            )
        }
    }

    private func lineEnd(imageCenter: CGPoint, imageSize: CGSize) -> CGPoint {
        switch size {
        case .large:
            return CGPoint(x: imageCenter.x, y: imageCenter.y + imageSize.height / 2)
        case .none, .small, .medium:
            return CGPoint(
                x: imageCenter.x - imageSize.width / 2,
                y: imageCenter.y + imageSize.height / 2
            )
        }
    }
}

// MARK: - コース概要シート

private struct CourseSummarySheet: View {
    let course: Course
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // カバー画像（ローカル優先、なければリモートURL）
                    if let uiImage = course.localCoverImagePath.flatMap({ LocalImageStorage.shared.load(from: $0) }) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipped()
                    } else if let urlStr = course.coverImageUrl, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            if case .success(let image) = phase {
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 200)
                                    .clipped()
                            } else {
                                Color.indigo.opacity(0.15)
                                    .frame(height: 200)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        // 概要テキスト
                        if let summary = course.summary {
                            Text(summary)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // 画像クレジット（説明文末尾）
                        if let credit = course.imageCredit, !credit.isEmpty {
                            Text(credit)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // 更新日
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                            Text(L.Course.updatedAt(course.updatedAt.formatted(.dateTime.year().month().day())))
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding()
                }
            }
            .navigationTitle(course.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.Common.close) { dismiss() }
                }
            }
        }
        .iPadSheetSize(iPhoneDetents: [.medium, .large])
    }
}

// MARK: - 地図設定シート（SpotListScreen と共有）

struct CourseMapSettingsSheet: View {
    @Binding var zoomOnSpotFocus: Bool
    @Binding var spotPhotoSizeRaw: String
    @Environment(\.dismiss) private var dismiss

    private var selectedPhotoSize: CourseSpotPhotoSize {
        CourseSpotPhotoSize(rawValue: spotPhotoSizeRaw) ?? .large
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("スポットフォーカス時のズーム")
                        .font(.headline)
                    Text("スポットを選択したときに、地図をスポット中心へ移動しながらズームインするかを切り替えます。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 0) {
                    toggleButton(title: "ON", isSelected: zoomOnSpotFocus) {
                        withAnimation(.easeInOut(duration: 0.18)) { zoomOnSpotFocus = true }
                    }
                    toggleButton(title: "OFF", isSelected: !zoomOnSpotFocus) {
                        withAnimation(.easeInOut(duration: 0.18)) { zoomOnSpotFocus = false }
                    }
                }
                .padding(4)
                .background(Color.secondary.opacity(0.12), in: Capsule())

                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("スポット写真の大きさ")
                            .font(.headline)
                        Text("地図上に表示するスポット写真のサイズを選べます。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 0) {
                        ForEach(CourseSpotPhotoSize.allCases, id: \.rawValue) { size in
                            toggleButton(title: size.title, isSelected: selectedPhotoSize == size) {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    spotPhotoSizeRaw = size.rawValue
                                }
                            }
                        }
                    }
                    .padding(4)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("地図設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L.Common.done) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(340)])
    }

    private func toggleButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(isSelected ? Color.indigo : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

