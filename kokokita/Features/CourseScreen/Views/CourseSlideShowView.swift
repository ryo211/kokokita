import SwiftUI
import MapKit
import UIKit

// MARK: - アニメーション速度設定

enum SlideShowAnimationSpeed: String, CaseIterable {
    case slow
    case medium
    case fast

    var title: String {
        switch self {
        case .slow: return L.SlideShow.speedSlow
        case .medium: return L.SlideShow.speedMedium
        case .fast: return L.SlideShow.speedFast
        }
    }

    var transitionDuration: Double {
        switch self {
        case .slow: return 1.35
        case .medium: return 0.9
        case .fast: return 0.48
        }
    }
}

enum SlideShowPhotoPresentation: String, CaseIterable {
    case layered
    case mainOnly

    var title: String {
        switch self {
        case .layered: return "背景あり"
        case .mainOnly: return "写真のみ"
        }
    }
}

enum SlideShowMapScope: String, CaseIterable {
    case japan
    case section

    var title: String {
        switch self {
        case .japan: return "日本全体"
        case .section: return "セクション別"
        }
    }
}

// MARK: - スライドショー（動画モード）

struct CourseSlideShowView: View {
    let course: Course

    @Environment(AppUIState.self) private var appUIState

    @AppStorage("slideShow.intervalSeconds") private var intervalSeconds: Double = 3.0
    @AppStorage("slideShow.animationSpeedRaw") private var animationSpeedRaw: String = SlideShowAnimationSpeed.medium.rawValue
    @AppStorage("slideShow.photoPresentationRaw") private var photoPresentationRaw: String = SlideShowPhotoPresentation.layered.rawValue
    @AppStorage("slideShow.mapScopeRaw") private var mapScopeRaw: String = SlideShowMapScope.japan.rawValue
    @AppStorage("slideShow.showsMap") private var showsMap = true
    @AppStorage("slideShow.showsEndPromotion") private var showsEndPromotion = true

    @State private var currentIndex = 0
    @State private var isPlaying = false
    @State private var showSettings = false
    @State private var showControls = false
    @State private var controlsHideTask: Task<Void, Never>?
    @State private var playbackTask: Task<Void, Never>?
    @State private var preparationTask: Task<Void, Never>?
    @State private var preparedImageIds: Set<UUID> = []
    @State private var preparationProgress = 0.0
    @State private var isPreparing = true
    @State private var isShowingCourseIntro = true
    @State private var isShowingEndPromotion = false
    @State private var outgoingSpot: CourseSpot?
    @State private var outgoingSpotNumber = 1
    @State private var outgoingOpacity = 0.0
    @State private var outgoingClearTask: Task<Void, Never>?
    @State private var introMapOffset: CGSize = .zero
    @State private var introMapDragTranslation: CGSize = .zero
    @State private var selectedSpotIds: Set<UUID> = []

    /// 動画で見栄えが成立するよう、写真付きスポットのみを対象にする。
    private var allPhotoSpots: [CourseSpot] {
        course.spots.filter { $0.localCoverImagePath != nil || $0.coverImageUrl != nil }
    }

    private var playableSpots: [CourseSpot] {
        guard !selectedSpotIds.isEmpty else { return allPhotoSpots }
        return allPhotoSpots.filter { selectedSpotIds.contains($0.id) }
    }

    private var currentSpot: CourseSpot? {
        playableSpots.indices.contains(currentIndex) ? playableSpots[currentIndex] : nil
    }

    private var animationSpeed: SlideShowAnimationSpeed {
        SlideShowAnimationSpeed(rawValue: animationSpeedRaw) ?? .medium
    }

    private var photoPresentation: SlideShowPhotoPresentation {
        SlideShowPhotoPresentation(rawValue: photoPresentationRaw) ?? .layered
    }

    private var mapScope: SlideShowMapScope {
        if mapScopeRaw == "course" {
            return .section
        }
        return SlideShowMapScope(rawValue: mapScopeRaw) ?? .japan
    }

    private var currentSection: CourseSection? {
        guard let currentSpot else { return nil }
        return course.sections.first { section in
            section.spots.contains { $0.id == currentSpot.id }
        }
    }

    private var currentSectionPlayableSpots: [CourseSpot] {
        guard let currentSection else { return playableSpots }
        let playableIds = Set(playableSpots.map(\.id))
        return currentSection.spots.filter { playableIds.contains($0.id) }
    }

    private var locatorMapSpots: [CourseSpot] {
        switch mapScope {
        case .japan:
            return playableSpots
        case .section:
            return currentSectionPlayableSpots
        }
    }

    private var locatorMapRegion: MKCoordinateRegion {
        switch mapScope {
        case .japan:
            return JapanLocatorMap.japanRegion
        case .section:
            return Self.fitRegion(for: currentSectionPlayableSpots)
        }
    }

    private var locatorMapLabel: String? {
        guard mapScope == .section,
              let currentSection,
              currentSection.hasName else {
            return nil
        }
        return currentSection.name
    }

    /// TikTok向けに読める最低時間を確保する。既存保存値が範囲外でも補正する。
    private var clampedInterval: Double {
        min(max(1.5, intervalSeconds), 5.0)
    }

    var body: some View {
        Group {
            if playableSpots.isEmpty {
                emptyView
            } else {
                contentView
            }
        }
        .onAppear {
            appUIState.isTabBarHidden = true
            initializeSelectedSpotsIfNeeded()
            beginPreparation()
        }
        .onDisappear {
            appUIState.isTabBarHidden = false
            stopPlayback()
            preparationTask?.cancel()
            controlsHideTask?.cancel()
            outgoingClearTask?.cancel()
        }
    }

    // MARK: - コンテンツ

    private var contentView: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                if isShowingCourseIntro {
                    CourseIntroStage(
                        course: course,
                        image: CourseSlideShowImageCache.shared.cachedImage(for: course),
                        safeTop: geo.safeAreaInsets.top,
                        safeBottom: geo.safeAreaInsets.bottom
                    )
                } else if isShowingEndPromotion {
                    KokokitaEndPromotionStage(
                        safeTop: geo.safeAreaInsets.top,
                        safeBottom: geo.safeAreaInsets.bottom
                    )
                } else if let spot = currentSpot {
                    stageView(
                        spot: spot,
                        spotNumber: currentIndex + 1,
                        safeTop: geo.safeAreaInsets.top,
                        safeBottom: geo.safeAreaInsets.bottom
                    )
                }

                if let outgoingSpot {
                    stageView(
                        spot: outgoingSpot,
                        spotNumber: outgoingSpotNumber,
                        safeTop: geo.safeAreaInsets.top,
                        safeBottom: geo.safeAreaInsets.bottom
                    )
                    .compositingGroup()
                    .opacity(outgoingOpacity)
                    .allowsHitTesting(false)
                }

                locatorMapOverlay(geo: geo)
                introMapOverlay(geo: geo)

                controlsOverlay(safeBottom: geo.safeAreaInsets.bottom)
                    .opacity(showControls ? 1 : 0)
                    .allowsHitTesting(showControls)

                preparationOverlay
            }
            .contentShape(Rectangle())
            .onTapGesture { toggleControls() }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showSettings = true } label: {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(.white)
                }
            }
        }
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showSettings) {
            SlideShowSettingsSheet(
                intervalSeconds: $intervalSeconds,
                animationSpeedRaw: $animationSpeedRaw,
                photoPresentationRaw: $photoPresentationRaw,
                mapScopeRaw: $mapScopeRaw,
                showsMap: $showsMap,
                showsEndPromotion: $showsEndPromotion,
                spots: allPhotoSpots,
                selectedSpotIds: $selectedSpotIds
            )
        }
        .onChange(of: clampedInterval) { _, _ in restartPlaybackIfNeeded() }
        .onChange(of: animationSpeedRaw) { _, _ in restartPlaybackIfNeeded() }
        .onChange(of: selectedSpotIds) { _, _ in
            restartAfterSpotSelectionChange()
        }
    }

    private func stageView(
        spot: CourseSpot,
        spotNumber: Int,
        safeTop: CGFloat,
        safeBottom: CGFloat
    ) -> some View {
        CinematicSpotStage(
            course: course,
            spot: spot,
            spotNumber: spotNumber,
            image: CourseSlideShowImageCache.shared.cachedImage(for: spot),
            photoPresentation: photoPresentation,
            safeTop: safeTop,
            safeBottom: safeBottom
        )
    }

    @ViewBuilder
    private func locatorMapOverlay(geo: GeometryProxy) -> some View {
        if !isShowingCourseIntro, !isShowingEndPromotion, showsMap, let spot = currentSpot, spot.hasValidCoordinate {
            let mapSize = spotMapSize(for: geo)
            let mapWidth = mapSize.width
            let mapHeight = mapSize.height
            JapanLocatorMap(
                spots: locatorMapSpots,
                currentSpotId: spot.id,
                region: locatorMapRegion,
                label: locatorMapLabel
            )
            .frame(width: mapWidth, height: mapHeight)
            .opacity(0.5)
            .position(
                x: geo.size.width - 16 - mapWidth / 2,
                y: geo.safeAreaInsets.top + 274 + mapHeight / 2
            )
        }
    }

    private func spotMapSize(for geo: GeometryProxy) -> CGSize {
        switch mapScope {
        case .japan:
            return CGSize(width: min(geo.size.width * 0.31, 128), height: 156)
        case .section:
            let side = min(geo.size.width * 0.27, 108)
            return CGSize(width: side, height: side)
        }
    }

    @ViewBuilder
    private func introMapOverlay(geo: GeometryProxy) -> some View {
        if isShowingCourseIntro, showsMap {
            let mapWidth = min(geo.size.width * 0.34, 138)
            let mapHeight: CGFloat = 168
            let defaultPosition = CGPoint(
                x: geo.size.width - 18 - mapWidth / 2,
                y: geo.safeAreaInsets.top + 172 + mapHeight / 2
            )
            let position = clampedIntroMapPosition(
                proposed: CGPoint(
                    x: defaultPosition.x + introMapOffset.width + introMapDragTranslation.width,
                    y: defaultPosition.y + introMapOffset.height + introMapDragTranslation.height
                ),
                mapSize: CGSize(width: mapWidth, height: mapHeight),
                geo: geo
            )

            ZStack {
                JapanLocatorMap(
                    spots: playableSpots,
                    currentSpotId: nil,
                    region: JapanLocatorMap.japanRegion,
                    label: nil
                )
                .allowsHitTesting(false)

                Color.clear
                    .contentShape(Rectangle())
            }
            .frame(width: mapWidth, height: mapHeight)
            .opacity(0.56)
            .position(position)
            .highPriorityGesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        introMapDragTranslation = value.translation
                    }
                    .onEnded { value in
                        let committedPosition = clampedIntroMapPosition(
                            proposed: CGPoint(
                                x: defaultPosition.x + introMapOffset.width + value.translation.width,
                                y: defaultPosition.y + introMapOffset.height + value.translation.height
                            ),
                            mapSize: CGSize(width: mapWidth, height: mapHeight),
                            geo: geo
                        )
                        introMapOffset = CGSize(
                            width: committedPosition.x - defaultPosition.x,
                            height: committedPosition.y - defaultPosition.y
                        )
                        introMapDragTranslation = .zero
                    }
            )
        }
    }

    private func clampedIntroMapPosition(
        proposed: CGPoint,
        mapSize: CGSize,
        geo: GeometryProxy
    ) -> CGPoint {
        let horizontalPadding: CGFloat = 14
        let verticalPadding: CGFloat = 14
        let minX = horizontalPadding + mapSize.width / 2
        let maxX = geo.size.width - horizontalPadding - mapSize.width / 2
        let minY = geo.safeAreaInsets.top + verticalPadding + mapSize.height / 2
        let maxY = geo.size.height - geo.safeAreaInsets.bottom - verticalPadding - mapSize.height / 2

        return CGPoint(
            x: min(max(proposed.x, minX), maxX),
            y: min(max(proposed.y, minY), maxY)
        )
    }

    private var preparationOverlay: some View {
        Group {
            if isPreparing {
                VideoPreparationOverlay(progress: preparationProgress)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isPreparing)
    }

    private func controlsOverlay(safeBottom: CGFloat) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 16) {
                Button { restartFromBeginning() } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 19, weight: .bold))
                        .frame(width: 46, height: 52)
                }
                .disabled(isShowingCourseIntro)
                .opacity(isShowingCourseIntro ? 0.35 : 1)

                Button { previous() } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 22, weight: .bold))
                        .frame(width: 46, height: 52)
                }
                .disabled(isShowingCourseIntro || isShowingEndPromotion || currentIndex == 0)
                .opacity(isShowingCourseIntro || isShowingEndPromotion || currentIndex == 0 ? 0.35 : 1)

                Button {
                    isPlaying ? pausePlayback() : resumePlayback()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 30, weight: .bold))
                        .frame(width: 64, height: 64)
                        .contentTransition(.symbolEffect(.replace))
                }

                Button { next() } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 22, weight: .bold))
                        .frame(width: 46, height: 52)
                }
                .disabled(isShowingCourseIntro || isShowingEndPromotion || currentIndex >= playableSpots.count - 1)
                .opacity(isShowingCourseIntro || isShowingEndPromotion || currentIndex >= playableSpots.count - 1 ? 0.35 : 1)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.bottom, max(safeBottom, 16))
        }
        .animation(.easeInOut(duration: 0.25), value: showControls)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(L.SlideShow.noPlayableSpots)
                .font(.headline)
            Text(L.SlideShow.noPlayableSpotsDesc)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - 準備と再生

    private func beginPreparation() {
        initializeSelectedSpotsIfNeeded()
        preparationTask?.cancel()
        playbackTask?.cancel()
        isPreparing = true
        isPlaying = false
        isShowingCourseIntro = true
        isShowingEndPromotion = false
        showControls = false
        currentIndex = 0
        introMapOffset = .zero
        introMapDragTranslation = .zero
        outgoingSpot = nil
        outgoingOpacity = 0
        preparationProgress = 0
        preparedImageIds.removeAll()

        preparationTask = Task {
            await preloadInitialWindow()
            guard !Task.isCancelled else { return }
        }
    }

    private func initializeSelectedSpotsIfNeeded() {
        guard selectedSpotIds.isEmpty else { return }
        selectedSpotIds = Set(allPhotoSpots.map(\.id))
    }

    private func restartAfterSpotSelectionChange() {
        guard !allPhotoSpots.isEmpty else { return }
        currentIndex = 0
        isShowingCourseIntro = true
        isShowingEndPromotion = false
        showControls = false
        stopPlayback()
        beginPreparation()
    }

    private func preloadInitialWindow() async {
        let initialCount = min(playableSpots.count, 4)
        guard initialCount > 0 else { return }

        await loadCourseImageIfNeeded()
        await MainActor.run {
            preparationProgress = 0.18
        }

        for index in 0..<initialCount {
            guard !Task.isCancelled else { return }
            await loadImageIfNeeded(at: index)
            await MainActor.run {
                preparationProgress = 0.18 + (Double(index + 1) / Double(initialCount)) * 0.82
            }
        }

        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.28)) {
                isPreparing = false
                showControls = false
            }
        }

        Task {
            for index in initialCount..<playableSpots.count {
                guard !Task.isCancelled else { return }
                await loadImageIfNeeded(at: index)
            }
        }
    }

    private func resumePlayback() {
        guard !isPreparing else { return }
        if isShowingCourseIntro {
            withAnimation(.easeInOut(duration: animationSpeed.transitionDuration)) {
                isShowingCourseIntro = false
            }
        } else if isShowingEndPromotion {
            isShowingEndPromotion = false
            currentIndex = 0
        }
        isPlaying = true
        showControls = false
        startPlaybackLoop()
    }

    private func pausePlayback() {
        isPlaying = false
        playbackTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) { showControls = true }
    }

    private func stopPlayback() {
        isPlaying = false
        playbackTask?.cancel()
    }

    private func startPlaybackLoop() {
        playbackTask?.cancel()
        playbackTask = Task {
            while !Task.isCancelled {
                await preloadAhead(from: currentIndex)
                try? await Task.sleep(nanoseconds: UInt64(clampedInterval * 1_000_000_000))
                guard !Task.isCancelled else { return }

                if currentIndex >= playableSpots.count - 1 {
                    await MainActor.run {
                        isPlaying = false
                        showControls = false
                        if showsEndPromotion {
                            withAnimation(.easeInOut(duration: animationSpeed.transitionDuration)) {
                                isShowingEndPromotion = true
                            }
                        }
                    }
                    return
                }

                await loadImageIfNeeded(at: currentIndex + 1)
                await MainActor.run {
                    moveToIndex(currentIndex + 1)
                }
            }
        }
    }

    private func restartPlaybackIfNeeded() {
        if isPlaying {
            startPlaybackLoop()
        }
    }

    private func moveToIndex(_ newIndex: Int) {
        guard playableSpots.indices.contains(newIndex),
              newIndex != currentIndex,
              playableSpots.indices.contains(currentIndex) else {
            return
        }

        outgoingClearTask?.cancel()
        let previousSpot = playableSpots[currentIndex]
        var setupTransaction = Transaction()
        setupTransaction.disablesAnimations = true
        withTransaction(setupTransaction) {
            outgoingSpot = previousSpot
            outgoingSpotNumber = currentIndex + 1
            outgoingOpacity = 1
            currentIndex = newIndex
        }

        let duration = max(animationSpeed.transitionDuration, 0.24)
        outgoingClearTask = Task {
            await Task.yield()
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: duration)) {
                    outgoingOpacity = 0
                }
            }

            try? await Task.sleep(nanoseconds: UInt64((duration + 0.08) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                outgoingSpot = nil
                outgoingOpacity = 0
            }
        }
    }

    private func preloadAhead(from index: Int) async {
        let startIndex = index + 1
        let endIndex = min(index + 3, playableSpots.count - 1)
        guard startIndex <= endIndex else { return }

        for nextIndex in startIndex...endIndex {
            await loadImageIfNeeded(at: nextIndex)
        }
    }

    private func loadImageIfNeeded(at index: Int) async {
        guard playableSpots.indices.contains(index) else { return }
        let spot = playableSpots[index]
        if CourseSlideShowImageCache.shared.cachedImage(for: spot) == nil {
            _ = await CourseSlideShowImageCache.shared.image(for: spot)
        }
        await MainActor.run {
            preparedImageIds.insert(spot.id)
        }
    }

    private func loadCourseImageIfNeeded() async {
        if CourseSlideShowImageCache.shared.cachedImage(for: course) == nil {
            _ = await CourseSlideShowImageCache.shared.image(for: course)
        }
    }

    private static func fitRegion(for spots: [CourseSpot]) -> MKCoordinateRegion {
        let validSpots = spots.filter(\.hasValidCoordinate)
        guard !validSpots.isEmpty else {
            return JapanLocatorMap.japanRegion
        }

        guard validSpots.count > 1 else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: validSpots[0].latitude,
                    longitude: validSpots[0].longitude
                ),
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        }

        let lats = validSpots.map(\.latitude)
        let lons = validSpots.map(\.longitude)
        let minLat = lats.min()!
        let maxLat = lats.max()!
        let minLon = lons.min()!
        let maxLon = lons.max()!

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let latitudeDelta = max((maxLat - minLat) * 1.5, 0.01)
        let longitudeDelta = max((maxLon - minLon) * 1.5, 0.01)

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }

    // MARK: - 手動操作

    private func toggleControls() {
        guard !isPreparing else { return }
        controlsHideTask?.cancel()

        if isShowingCourseIntro {
            resumePlayback()
            return
        }

        if showControls {
            withAnimation(.easeInOut(duration: 0.25)) { showControls = false }
        } else {
            revealControls()
        }
    }

    private func revealControls() {
        guard !isPreparing else { return }
        controlsHideTask?.cancel()
        withAnimation(.easeInOut(duration: 0.25)) { showControls = true }
        guard isPlaying else { return }
        controlsHideTask = Task {
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.35)) { showControls = false }
            }
        }
    }

    private func next() {
        guard currentIndex < playableSpots.count - 1 else { return }
        Task {
            await loadImageIfNeeded(at: currentIndex + 1)
            await MainActor.run {
                moveToIndex(currentIndex + 1)
                if isPlaying { startPlaybackLoop() }
                revealControls()
            }
        }
    }

    private func previous() {
        guard currentIndex > 0 else { return }
        moveToIndex(currentIndex - 1)
        if isPlaying { startPlaybackLoop() }
        revealControls()
    }

    private func restartFromBeginning() {
        guard !isShowingCourseIntro else { return }
        Task {
            await loadCourseImageIfNeeded()
            await MainActor.run {
                playbackTask?.cancel()
                isPlaying = false
                outgoingClearTask?.cancel()
                outgoingSpot = nil
                outgoingOpacity = 0
                currentIndex = 0
                withAnimation(.easeInOut(duration: animationSpeed.transitionDuration)) {
                    isShowingCourseIntro = true
                    isShowingEndPromotion = false
                    showControls = false
                }
            }
        }
    }

}

// MARK: - ブランド表示

private struct KokokitaVideoBrandBadge: View {
    var body: some View {
        HStack(spacing: 5) {
            Image("kokokita-app-icon-clearBlueDeep")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

            Text("ココキタ")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.leading, 7)
        .padding(.trailing, 9)
        .padding(.vertical, 5)
        .background(.black.opacity(0.34), in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.indigo.opacity(0.55), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.32), radius: 8, x: 0, y: 4)
        .allowsHitTesting(false)
    }
}

struct KokokitaEndPromotionStage: View {
    let safeTop: CGFloat
    let safeBottom: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.05, blue: 0.12),
                    Color.indigo.opacity(0.95),
                    Color(red: 0.0, green: 0.0, blue: 0.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Image("kokokita-app-icon-clearBlueDeep")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: .black.opacity(0.35), radius: 22, x: 0, y: 12)

                VStack(spacing: 8) {
                    Text("ココキタ")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.42), radius: 10, x: 0, y: 5)

                    Text("聖地巡礼・訪問記録アプリ")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white.opacity(0.88))
                }

                Text("App Store「ココキタ」で検索🔍")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.82))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.22), in: Capsule())
                    .padding(.top, 8)
            }
            .padding(.horizontal, 28)
            .padding(.top, safeTop)
            .padding(.bottom, safeBottom)
        }
    }
}

// MARK: - 動画ステージ

private struct CourseIntroStage: View {
    let course: Course
    let image: UIImage?
    let safeTop: CGFloat
    let safeBottom: CGFloat

    var body: some View {
        GeometryReader { geo in
            ZStack {
                heroImage
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.62), location: 0),
                        .init(color: .black.opacity(0.10), location: 0.34),
                        .init(color: .black.opacity(0.24), location: 0.58),
                        .init(color: .black.opacity(0.88), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        KokokitaVideoBrandBadge()
                        Spacer()
                    }

                    Spacer()

                    if !course.categories.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(course.categories.prefix(3), id: \.rawValue) { category in
                                Label(category.displayName, systemImage: category.iconName)
                                    .font(.system(size: 12, weight: .black))
                                    .lineLimit(1)
                                    .foregroundStyle(.white.opacity(0.9))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 6)
                                    .background(.black.opacity(0.38), in: Capsule())
                            }
                        }
                    }

                    Text(course.title)
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(4)
                        .minimumScaleFactor(0.72)
                        .shadow(color: .black.opacity(0.72), radius: 13, x: 0, y: 6)

                    if let summary = course.summary?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !summary.isEmpty {
                        Text(summary)
                            .font(.system(size: 17, weight: .semibold))
                            .lineSpacing(4)
                            .foregroundStyle(.white.opacity(0.94))
                            .lineLimit(6)
                            .minimumScaleFactor(0.82)
                            .shadow(color: .black.opacity(0.72), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(.top, safeTop + 16)
                .padding(.horizontal, 22)
                .padding(.bottom, max(safeBottom + 34, 44))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var heroImage: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(.horizontal, 12)
                        .padding(.top, 88)
                        .padding(.bottom, 284)
                        .shadow(color: .black.opacity(0.48), radius: 22, x: 0, y: 12)
                        .opacity(0.92)
                }
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.06, blue: 0.12),
                    Color.indigo.opacity(0.85),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct CinematicSpotStage: View {
    let course: Course
    let spot: CourseSpot
    let spotNumber: Int
    let image: UIImage?
    let photoPresentation: SlideShowPhotoPresentation
    let safeTop: CGFloat
    let safeBottom: CGFloat

    var body: some View {
        GeometryReader { geo in
            ZStack {
                heroImage
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.56), location: 0),
                        .init(color: .black.opacity(0.08), location: 0.32),
                        .init(color: .black.opacity(0.18), location: 0.58),
                        .init(color: .black.opacity(0.88), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                topChrome
                    .padding(.top, safeTop + 12)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                editorialTextBlock
                    .padding(.horizontal, 22)
                    .padding(.bottom, max(safeBottom + 24, 34))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
    }

    @ViewBuilder
    private var heroImage: some View {
        if let image {
            switch photoPresentation {
            case .layered:
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .overlay {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding(.horizontal, 10)
                            .padding(.top, 74)
                            .padding(.bottom, 250)
                            .shadow(color: .black.opacity(0.52), radius: 24, x: 0, y: 14)
                            .opacity(0.94)
                    }

            case .mainOnly:
                ZStack {
                    Color.black
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(.horizontal, 8)
                        .padding(.top, 82)
                        .padding(.bottom, 248)
                        .shadow(color: .black.opacity(0.46), radius: 18, x: 0, y: 10)
                }
            }
        } else {
            LinearGradient(
                colors: [.black, Color(red: 0.12, green: 0.12, blue: 0.16)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var topChrome: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(course.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(.white.opacity(0.82))

                Text("\(spotNumber)")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.55), radius: 9, x: 0, y: 4)
            }

            Spacer()
        }
    }

    private var editorialTextBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(spot.name)
                .font(.system(size: 31, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(3)
                .minimumScaleFactor(0.76)
                .shadow(color: .black.opacity(0.7), radius: 11, x: 0, y: 5)

            if let desc = spot.spotDescription?.trimmingCharacters(in: .whitespacesAndNewlines),
               !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 17, weight: .semibold))
                    .lineSpacing(3)
                    .foregroundStyle(.white.opacity(0.94))
                    .lineLimit(5)
                    .minimumScaleFactor(0.84)
                    .shadow(color: .black.opacity(0.75), radius: 7, x: 0, y: 3)
            }

            HStack(alignment: .center, spacing: 8) {
                if let address = spot.address?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !address.isEmpty {
                    Label(address, systemImage: "mappin.and.ellipse")
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(1)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.42), in: Capsule())
                }

                Spacer(minLength: 8)

                KokokitaVideoBrandBadge()
            }
        }
    }
}

// MARK: - 日本位置インセット

private struct JapanLocatorMap: View {
    let spots: [CourseSpot]
    let currentSpotId: UUID?
    let region: MKCoordinateRegion
    let label: String?

    @State private var mapPosition: MapCameraPosition

    static let japanRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.5, longitude: 137.5),
        span: MKCoordinateSpan(latitudeDelta: 18.5, longitudeDelta: 20.0)
    )

    init(
        spots: [CourseSpot],
        currentSpotId: UUID?,
        region: MKCoordinateRegion,
        label: String?
    ) {
        self.spots = spots
        self.currentSpotId = currentSpotId
        self.region = region
        self.label = label
        _mapPosition = State(initialValue: .region(region))
    }

    var body: some View {
        Map(position: $mapPosition, interactionModes: []) {
            ForEach(spots.filter(\.hasValidCoordinate)) { spot in
                Annotation("", coordinate: CLLocationCoordinate2D(
                    latitude: spot.latitude,
                    longitude: spot.longitude
                ), anchor: .center) {
                    locatorPin(isCurrent: currentSpotId == spot.id)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted))
        .disabled(true)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .topLeading) {
            if let label {
                Text(label)
                    .font(.system(size: 10, weight: .black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.42), in: Capsule())
                    .padding(8)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.24), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.32), radius: 12, x: 0, y: 8)
        .onChange(of: regionSignature) { _, _ in
            withAnimation(.easeInOut(duration: 0.45)) {
                mapPosition = .region(region)
            }
        }
    }

    private var regionSignature: String {
        [
            region.center.latitude,
            region.center.longitude,
            region.span.latitudeDelta,
            region.span.longitudeDelta
        ]
        .map { String(format: "%.6f", $0) }
        .joined(separator: ":")
    }

    private func locatorPin(isCurrent: Bool) -> some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(isCurrent ? 0.24 : 0.001))
                .frame(width: isCurrent ? 28 : 12, height: isCurrent ? 28 : 12)
            Circle()
                .fill(Color.indigo)
                .frame(width: isCurrent ? 12 : 6, height: isCurrent ? 12 : 6)
                .overlay(Circle().stroke(.white.opacity(isCurrent ? 1 : 0.72), lineWidth: isCurrent ? 2 : 1))
                .opacity(isCurrent ? 1 : 0.48)
                .shadow(color: .black.opacity(isCurrent ? 0.34 : 0.18), radius: isCurrent ? 6 : 2, x: 0, y: 2)
        }
        .animation(.easeInOut(duration: 0.28), value: isCurrent)
    }
}

// MARK: - 準備表示

private struct VideoPreparationOverlay: View {
    let progress: Double

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "film.stack")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))

                VStack(spacing: 8) {
                    Text("動画用に写真を準備中")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("準備後に表紙を表示します")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.64))
                }

                ProgressView(value: progress)
                    .tint(.white)
                    .frame(width: 210)
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - 画像キャッシュ

private final class CourseSlideShowImageCache {
    static let shared = CourseSlideShowImageCache()

    private let cache = NSCache<NSString, UIImage>()
    private init() {
        cache.countLimit = 36
        cache.totalCostLimit = 120 * 1024 * 1024
    }

    func cachedImage(for spot: CourseSpot) -> UIImage? {
        cache.object(forKey: cacheKey(for: spot))
    }

    func cachedImage(for course: Course) -> UIImage? {
        cache.object(forKey: cacheKey(for: course))
    }

    func image(for spot: CourseSpot) async -> UIImage? {
        if let cached = cachedImage(for: spot) {
            return cached
        }

        if let path = spot.localCoverImagePath,
           let image = LocalImageStorage.shared.load(from: path) {
            store(image, for: spot)
            return image
        }

        guard let urlString = spot.coverImageUrl,
              let url = URL(string: urlString) else {
            return nil
        }

        do {
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let image = UIImage(data: data) else { return nil }
            store(image, for: spot)
            return image
        } catch {
            Logger.warning("動画モード画像の事前読み込みに失敗: \(error.localizedDescription)")
            return nil
        }
    }

    func image(for course: Course) async -> UIImage? {
        if let cached = cachedImage(for: course) {
            return cached
        }

        if let path = course.localCoverImagePath,
           let image = LocalImageStorage.shared.load(from: path) {
            store(image, for: course)
            return image
        }

        guard let urlString = course.coverImageUrl,
              let url = URL(string: urlString) else {
            return nil
        }

        do {
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let image = UIImage(data: data) else { return nil }
            store(image, for: course)
            return image
        } catch {
            Logger.warning("動画モードコース画像の事前読み込みに失敗: \(error.localizedDescription)")
            return nil
        }
    }

    private func store(_ image: UIImage, for spot: CourseSpot) {
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        cache.setObject(image, forKey: cacheKey(for: spot), cost: cost)
    }

    private func store(_ image: UIImage, for course: Course) {
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        cache.setObject(image, forKey: cacheKey(for: course), cost: cost)
    }

    private func cacheKey(for spot: CourseSpot) -> NSString {
        if let path = spot.localCoverImagePath {
            return "local:\(path)" as NSString
        }
        return "remote:\(spot.coverImageUrl ?? spot.id.uuidString)" as NSString
    }

    private func cacheKey(for course: Course) -> NSString {
        if let path = course.localCoverImagePath {
            return "course-local:\(path)" as NSString
        }
        return "course-remote:\(course.coverImageUrl ?? course.id.uuidString)" as NSString
    }
}

// MARK: - 再生設定シート

struct SlideShowSettingsSheet: View {
    @Binding var intervalSeconds: Double
    @Binding var animationSpeedRaw: String
    @Binding var photoPresentationRaw: String
    @Binding var mapScopeRaw: String
    @Binding var showsMap: Bool
    @Binding var showsEndPromotion: Bool
    let spots: [CourseSpot]
    @Binding var selectedSpotIds: Set<UUID>
    @Environment(\.dismiss) private var dismiss
    @State private var lightboxSpot: CourseSpot?

    private var selectedSpeed: SlideShowAnimationSpeed {
        SlideShowAnimationSpeed(rawValue: animationSpeedRaw) ?? .medium
    }

    private var selectedPhotoPresentation: SlideShowPhotoPresentation {
        SlideShowPhotoPresentation(rawValue: photoPresentationRaw) ?? .layered
    }

    private var selectedMapScope: SlideShowMapScope {
        if mapScopeRaw == "course" {
            return .section
        }
        return SlideShowMapScope(rawValue: mapScopeRaw) ?? .japan
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    playbackSettings
                    animationSettings
                    photoPresentationSettings
                    mapSettings

                    Toggle("最後にアプリ紹介を表示", isOn: $showsEndPromotion)
                        .font(.headline)
                        .tint(.indigo)

                    spotSelectionSection

                    VStack(alignment: .leading, spacing: 6) {
                        Text("録画のコツ")
                            .font(.headline)
                        Text("画面録画を開始してから動画モードを開き、表紙を確認して再生すると一定テンポでスポットを紹介できます。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(20)
            }
            .navigationTitle(L.SlideShow.settingsTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L.Common.done) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .fullScreenCover(item: $lightboxSpot) { spot in
                SlideShowSpotLightbox(spot: spot) {
                    lightboxSpot = nil
                }
            }
        }
        .presentationDetents([.height(590), .large])
    }

    private var playbackSettings: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L.SlideShow.settingsInterval)
                    .font(.headline)
                Spacer()
                Text(L.SlideShow.settingsIntervalSec(intervalSeconds))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Slider(value: $intervalSeconds, in: 1.5...5, step: 0.5)
                .tint(.indigo)

            HStack {
                Text("1.5秒")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("5秒")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var animationSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L.SlideShow.settingsAnimationSpeed)
                .font(.headline)

            segmentedPicker(SlideShowAnimationSpeed.allCases, selected: selectedSpeed) { speed in
                animationSpeedRaw = speed.rawValue
            } title: { $0.title }
        }
    }

    private var photoPresentationSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("写真の見せ方")
                .font(.headline)

            segmentedPicker(SlideShowPhotoPresentation.allCases, selected: selectedPhotoPresentation) { presentation in
                photoPresentationRaw = presentation.rawValue
            } title: { $0.title }
        }
    }

    private var mapSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("地図を表示", isOn: $showsMap)
                .font(.headline)
                .tint(.indigo)

            Text("地図の表示範囲")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(showsMap ? .primary : .secondary)

            segmentedPicker(SlideShowMapScope.allCases, selected: selectedMapScope) { scope in
                mapScopeRaw = scope.rawValue
            } title: { $0.title }
            .disabled(!showsMap)
            .opacity(showsMap ? 1 : 0.45)
        }
    }

    private var spotSelectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("再生するスポット")
                    .font(.headline)
                Spacer()
                Text("\(selectedSpotIds.count)/\(spots.count)")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button("全件選択") {
                    selectedSpotIds = Set(spots.map(\.id))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(selectedSpotIds.count == spots.count)

                Button("全件解除") {
                    if let first = spots.first {
                        selectedSpotIds = [first.id]
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(spots.count <= 1 || selectedSpotIds.count == 1)
            }

            VStack(spacing: 0) {
                ForEach(spots) { spot in
                    SlideShowSpotSelectionRow(
                        spot: spot,
                        isSelected: selectedSpotIds.contains(spot.id),
                        isLastSelected: selectedSpotIds.count == 1 && selectedSpotIds.contains(spot.id),
                        onToggle: { toggleSpot(spot) },
                        onImageTap: { lightboxSpot = spot }
                    )

                    if spot.id != spots.last?.id {
                        Divider().padding(.leading, 70)
                    }
                }
            }
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func toggleSpot(_ spot: CourseSpot) {
        if selectedSpotIds.contains(spot.id) {
            guard selectedSpotIds.count > 1 else { return }
            selectedSpotIds.remove(spot.id)
        } else {
            selectedSpotIds.insert(spot.id)
        }
    }

    private func segmentedPicker<T: Hashable>(
        _ values: [T],
        selected: T,
        onSelect: @escaping (T) -> Void,
        title: @escaping (T) -> String
    ) -> some View {
        HStack(spacing: 0) {
            ForEach(values, id: \.self) { value in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        onSelect(value)
                    }
                } label: {
                    Text(title(value))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selected == value ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(selected == value ? Color.indigo : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.secondary.opacity(0.12), in: Capsule())
    }
}

private struct SlideShowSpotSelectionRow: View {
    let spot: CourseSpot
    let isSelected: Bool
    let isLastSelected: Bool
    let onToggle: () -> Void
    let onImageTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onImageTap) {
                SlideShowSpotImage(spot: spot, contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            Text(spot.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)

            Spacer()

            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.indigo : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(isLastSelected)
            .opacity(isLastSelected ? 0.55 : 1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isLastSelected else { return }
            onToggle()
        }
    }
}

private struct SlideShowSpotImage: View {
    enum ContentMode {
        case fill
        case fit
    }

    let spot: CourseSpot
    let contentMode: ContentMode

    var body: some View {
        Group {
            if let image = CourseSlideShowImageCache.shared.cachedImage(for: spot) {
                swiftUIImage(image)
            } else if let path = spot.localCoverImagePath,
                      let image = LocalImageStorage.shared.load(from: path) {
                swiftUIImage(image)
            } else if let urlString = spot.coverImageUrl,
                      let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        switch contentMode {
                        case .fill:
                            image.resizable().scaledToFill()
                        case .fit:
                            image.resizable().scaledToFit()
                        }
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .clipped()
    }

    private func swiftUIImage(_ uiImage: UIImage) -> some View {
        let image = Image(uiImage: uiImage).resizable()
        return Group {
            switch contentMode {
            case .fill:
                image.scaledToFill()
            case .fit:
                image.scaledToFit()
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            Color.secondary.opacity(0.16)
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
        }
    }
}

private struct SlideShowSpotLightbox: View {
    let spot: CourseSpot
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            SlideShowSpotImage(spot: spot, contentMode: .fit)
                .padding(18)

            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(.black.opacity(0.46), in: Circle())
                    }
                }
                Spacer()
                Text(spot.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.42), in: Capsule())
            }
            .padding(18)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onDismiss)
    }
}
