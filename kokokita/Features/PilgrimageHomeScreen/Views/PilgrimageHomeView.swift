import SwiftUI
import CoreLocation

// 巡礼モードのホーム画面（設計書 6.2 実装版）
// isPresented と値ベースナビゲーションの混在を避けるため、
// NavigationLink(value:) で統一する
struct PilgrimageHomeView: View {
    @State private var store = CourseListStore()
    @State private var userLocation: CLLocation? = CLLocationManager().location
    @State private var isRefreshingNearbySpots = false
    @State private var showSettings = false
    @State private var showHowToUse = false
    @State private var selectedCourseIndex = 0
    @State private var selectedCourseDetailRoute: SelectedCourseRoute?
    @State private var selectedSpotPanelIndex = 0

    @Environment(\.spotFavoriteStore) private var favoriteStore

    // MARK: - Derived Data

    /// お気に入りスポット（最大5件）
    private var favoriteSpots: [(course: Course, spot: CourseSpot)] {
        var results: [(course: Course, spot: CourseSpot)] = []
        for course in store.courses {
            for spot in course.spots where favoriteStore.isFavorite(spot.id) {
                results.append((course, spot))
            }
        }
        return Array(results.prefix(5))
    }

    /// 未達成の近傍スポット（距離昇順、最大5件）
    private var nearbySpots: [(course: Course, spot: CourseSpot, distance: Double)] {
        guard let location = userLocation else { return [] }
        var results: [(course: Course, spot: CourseSpot, distance: Double)] = []
        for course in store.courses {
            for spot in course.spots where !spot.isCheckedIn {
                let spotLoc = CLLocation(latitude: spot.latitude, longitude: spot.longitude)
                results.append((course, spot, location.distance(from: spotLoc)))
            }
        }
        return Array(results.sorted { $0.distance < $1.distance }.prefix(5))
    }

    /// 達成済みスポット（firstCheckedInAt 降順、最大5件）
    private var recentAchievements: [(course: Course, spot: CourseSpot)] {
        var results: [(course: Course, spot: CourseSpot)] = []
        for course in store.courses {
            for spot in course.spots where spot.isCheckedIn {
                results.append((course, spot))
            }
        }
        return Array(
            results
                .sorted { ($0.spot.firstCheckedInAt ?? .distantPast) > ($1.spot.firstCheckedInAt ?? .distantPast) }
                .prefix(5)
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.secondarySystemBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                PilgrimageMapBackgroundLayer(
                    config: PilgrimageMapBackgroundConfig(
                        style: .structured,
                        seed: 20250128,
                        lineWidth: 1.1,
                        blur: 1.2,
                        opacity: 0.08,
                        exclusionRadiusFactor: 0.18,
                        padding: 24,
                        offset: .zero,
                        organicLineCount: 26,
                        gridSpacing: 84,
                        gridJitter: 10,
                        gridStepMin: 0.75,
                        gridStepMax: 1.15,
                        diagonalChance: 0.4,
                        diagonalBackChance: 0.25,
                        diagonalStride: 2.2,
                        diagonalBackStride: 2.4
                    )
                )
                .ignoresSafeArea()

                Group {
                    if store.courses.isEmpty {
                        emptyCoursesView
                    } else {
                        mainContent
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showHowToUse = true
                    } label: {
                        Text(L.PilgrimageHome.howToUseButton)
                            .font(.subheadline)
                            .foregroundStyle(.indigo)
                    }
                }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.walk")
                            .foregroundStyle(.indigo)
                        Text(L.PilgrimageHome.navTitle)
                            .font(.headline)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundStyle(.indigo)
                    }
                    .accessibilityLabel(L.Menu.title)
                }
            }
            .sheet(isPresented: $showHowToUse) {
                PilgrimageHowToUseSheet()
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet()
            }
            .task {
                await store.load()
                userLocation = CLLocationManager().location
                normalizeSelectedCourseIndex()
            }
            .onReceive(NotificationCenter.default.publisher(for: .courseChanged)) { _ in
                Task { await store.load() }
                userLocation = CLLocationManager().location
            }
            .onChange(of: store.courses) { _, _ in
                normalizeSelectedCourseIndex()
            }
            // コース一覧・コース詳細・スポットパネルリストへの遷移
            .navigationDestination(for: PilgrimageHomeRoute.self) { route in
                switch route {
                case .courseList:
                    CourseListView(store: store)
                case .courseDetail(let courseId, let spotId):
                    if let course = store.courses.first(where: { $0.id == courseId }) {
                        CourseDetailView(course: course, initialSelectedSpotId: spotId)
                    }
                case .courseDetailSummary(let courseId):
                    if let course = store.courses.first(where: { $0.id == courseId }) {
                        CourseDetailView(course: course, showSummaryOnAppear: true)
                    }
                case .spotPanelList(let kind):
                    SpotPanelListView(kind: kind, store: store, userLocation: userLocation)
                }
            }
            // コース詳細への遷移（CourseListView が非ルートのためここで処理）
            .navigationDestination(item: $selectedCourseDetailRoute) { route in
                if let course = store.courses.first(where: { $0.id == route.id }) {
                    CourseDetailView(course: course, showSummaryOnAppear: true)
                }
            }
        }
    }

    // MARK: - コースなし状態

    private var emptyCoursesView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundStyle(.indigo.opacity(0.4))
            Text(L.Course.emptyTitle)
                .font(.title3.bold())
            Text(L.Course.emptyDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            NavigationLink(value: PilgrimageHomeRoute.courseList) {
                Label(L.PilgrimageHome.viewCourses, systemImage: "list.bullet")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - メインコンテンツ

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // ① コース一覧
                courseScrollSection
                    .padding(.bottom, 28)

                // ② スポット情報パネル
                spotPanelsSection
                    .padding(.bottom, 32)
            }
        }
    }

    // MARK: - ① コース横スクロール

    private var courseScrollSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            CourseSelectionCarousel(
                courses: store.courses,
                selectedIndex: $selectedCourseIndex,
                onCourseTap: { course in
                    selectedCourseDetailRoute = SelectedCourseRoute(id: course.id)
                }
            )
        }
    }

    // MARK: - ② スポット情報パネル

    private var spotPanelsSection: some View {
        VStack(spacing: 14) {
            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(index == selectedSpotPanelIndex ? Color.indigo.opacity(0.85) : Color.indigo.opacity(0.22))
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == selectedSpotPanelIndex ? 1.05 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: selectedSpotPanelIndex)
                    }
                }

                TabView(selection: $selectedSpotPanelIndex) {
                    nearbySection
                        .tag(0)

                    favoritesSection
                        .tag(1)

                    recentSection
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 492)
            }
            .padding(.top, 18)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.98))
                    .shadow(color: .black.opacity(0.1), radius: 18, x: 0, y: 10)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.indigo.opacity(0.08), lineWidth: 1.2)
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - ③ 近くのスポット

    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                NavigationLink(value: PilgrimageHomeRoute.spotPanelList(kind: .nearby)) {
                    SpotPanelHeader(
                        title: L.PilgrimageHome.nearbyTitle,
                        systemImage: "location.north.line.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                HStack {
                    Spacer()
                    Button {
                        Task { await refreshNearbySpots() }
                    } label: {
                        if isRefreshingNearbySpots {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.indigo)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isRefreshingNearbySpots)
                    .accessibilityLabel("近くの巡礼スポットを更新")
                }
            }
            .padding(.horizontal, 16)

            if nearbySpots.isEmpty {
                Text(userLocation == nil ? L.PilgrimageHome.locationUnavailable : L.PilgrimageHome.noNearbySpots)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(nearbySpots.enumerated()), id: \.element.spot.id) { index, item in
                        NavigationLink(value: PilgrimageHomeRoute.courseDetail(courseId: item.course.id, spotId: item.spot.id)) {
                            NearbySpotRow(course: item.course, spot: item.spot, distance: item.distance)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if index < nearbySpots.count - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .background(Color.white.opacity(0.78))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - ③ お気に入りスポット

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink(value: PilgrimageHomeRoute.spotPanelList(kind: .favorites)) {
                SpotPanelHeader(
                    title: L.SpotPanelList.favoritesTitle,
                    systemImage: "heart.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)

            if favoriteSpots.isEmpty {
                Text(L.SpotPanelList.noFavoritesShort)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.horizontal, 24)
                    .padding(.top, 72)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(favoriteSpots.enumerated()), id: \.element.spot.id) { index, item in
                        NavigationLink(value: PilgrimageHomeRoute.courseDetail(courseId: item.course.id, spotId: item.spot.id)) {
                            FavoriteSpotRow(course: item.course, spot: item.spot)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if index < favoriteSpots.count - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .background(Color.white.opacity(0.78))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - ④ 最近の達成

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink(value: PilgrimageHomeRoute.spotPanelList(kind: .recentAchievements)) {
                SpotPanelHeader(
                    title: L.PilgrimageHome.recentTitle,
                    systemImage: "checkmark.seal.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)

            if recentAchievements.isEmpty {
                Text(L.PilgrimageHome.noRecentAchievements)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.horizontal, 24)
                    .padding(.top, 72)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentAchievements.enumerated()), id: \.element.spot.id) { index, item in
                        NavigationLink(value: PilgrimageHomeRoute.courseDetail(courseId: item.course.id, spotId: item.spot.id)) {
                            RecentAchievementRow(course: item.course, spot: item.spot)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if index < recentAchievements.count - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .background(Color.white.opacity(0.78))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Actions

    @MainActor
    private func refreshNearbySpots() async {
        guard !isRefreshingNearbySpots else { return }
        isRefreshingNearbySpots = true

        do {
            let locationService = DefaultLocationService()
            let (location, _) = try await locationService.requestOneShotLocation(
                accuracy: kCLLocationAccuracyHundredMeters,
                timeout: 8.0
            )
            userLocation = location
        } catch {
            Logger.warning("Failed to refresh nearby pilgrimage spots location: \(error.localizedDescription)")
        }

        isRefreshingNearbySpots = false
    }

    private func normalizeSelectedCourseIndex() {
        guard !store.courses.isEmpty else {
            selectedCourseIndex = 0
            return
        }
        selectedCourseIndex = ((selectedCourseIndex % store.courses.count) + store.courses.count) % store.courses.count
    }
}

// MARK: - ① コース選択カルーセル

private struct CourseSelectionCarousel: View {
    let courses: [Course]
    @Binding var selectedIndex: Int
    let onCourseTap: (Course) -> Void

    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let centerCardWidth = min(width * 0.56, 268)
            let cardSpacing = centerCardWidth * 0.88

            ZStack {
                CourseCarouselStage()

                if courses.count == 1, let course = courses.first {
                    Button {
                        onCourseTap(course)
                    } label: {
                        CourseCarouselCard(course: course, style: .focused)
                            .frame(width: centerCardWidth)
                    }
                    .buttonStyle(.plain)
                } else if !courses.isEmpty {
                    ForEach(Array(courses.enumerated()), id: \.element.id) { index, course in
                        let progress = relativeProgress(for: index, dragOffset: dragOffset, cardSpacing: cardSpacing)

                        if abs(progress) < 2.4 {
                            Button {
                                handleTap(for: index, course: course)
                            } label: {
                                CourseCarouselCard(
                                    course: course,
                                    style: abs(progress) < 0.35 ? .focused : .side
                                )
                                .frame(width: centerCardWidth)
                            }
                            .buttonStyle(.plain)
                            .allowsHitTesting(abs(dragOffset) < 8)
                            .scaleEffect(cardScale(for: progress))
                            .rotationEffect(.degrees(cardTilt(for: progress)))
                            .rotation3DEffect(.degrees(cardYaw(for: progress)), axis: (x: 0, y: 1, z: 0), perspective: 0.8)
                            .offset(x: cardXOffset(for: progress, spacing: cardSpacing), y: cardYOffset(for: progress))
                            .opacity(cardOpacity(for: progress))
                            .zIndex(cardZIndex(for: progress))
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .highPriorityGesture(carouselGesture(cardSpacing: cardSpacing))
            .animation(.spring(response: 0.36, dampingFraction: 0.82), value: selectedIndex)
            .animation(.spring(response: 0.28, dampingFraction: 0.88), value: dragOffset)
        }
        .frame(height: 254)
    }

    private func handleTap(for index: Int, course: Course) {
        if index == wrappedIndex(selectedIndex) {
            onCourseTap(course)
        } else {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                selectedIndex = index
            }
        }
    }

    private func carouselGesture(cardSpacing: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($dragOffset) { value, state, _ in
                state = value.translation.width
            }
            .onEnded { value in
                let rawStep = -(value.predictedEndTranslation.width / cardSpacing)
                let clampedStep = max(-1, min(1, Int(round(rawStep))))

                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                    shiftSelection(by: clampedStep)
                }
            }
    }

    private func shiftSelection(by delta: Int) {
        guard !courses.isEmpty else { return }
        selectedIndex = wrappedIndex(selectedIndex + delta)
    }

    private func wrappedIndex(_ index: Int) -> Int {
        guard !courses.isEmpty else { return 0 }
        return ((index % courses.count) + courses.count) % courses.count
    }

    private func relativeProgress(for index: Int, dragOffset: CGFloat, cardSpacing: CGFloat) -> CGFloat {
        let relativeIndex = wrappedDistance(from: selectedIndex, to: index)
        let dragProgress = dragOffset / cardSpacing
        return CGFloat(relativeIndex) + dragProgress
    }

    private func wrappedDistance(from current: Int, to target: Int) -> Int {
        guard !courses.isEmpty else { return 0 }
        let forward = (target - current + courses.count) % courses.count
        let backward = forward - courses.count
        return abs(forward) <= abs(backward) ? forward : backward
    }

    private func cardXOffset(for progress: CGFloat, spacing: CGFloat) -> CGFloat {
        let sign: CGFloat = progress >= 0 ? 1 : -1
        let magnitude = min(abs(progress), 2.1)
        let eased = pow(magnitude, 0.92)
        return sign * eased * spacing
    }

    private func cardYOffset(for progress: CGFloat) -> CGFloat {
        6 + min(abs(progress), 1.8) * 19
    }

    private func cardScale(for progress: CGFloat) -> CGFloat {
        let distance = min(abs(progress), 2)
        return max(0.72, 1 - distance * 0.16)
    }

    private func cardOpacity(for progress: CGFloat) -> Double {
        let distance = min(abs(progress), 2)
        return max(0.26, 1 - Double(distance) * 0.32)
    }

    private func cardTilt(for progress: CGFloat) -> Double {
        Double(progress) * 9
    }

    private func cardYaw(for progress: CGFloat) -> Double {
        Double(progress) * -26
    }

    private func cardZIndex(for progress: CGFloat) -> Double {
        10 - Double(abs(progress))
    }
}

private struct CourseCarouselStage: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color.clear)
    }
}

private struct CourseCarouselCard: View {
    enum Style: Equatable {
        case focused
        case side

        var cardHeight: CGFloat {
            switch self {
            case .focused: 204
            case .side: 182
            }
        }

        var titleFont: Font {
            switch self {
            case .focused: .title3.weight(.bold)
            case .side: .headline.weight(.bold)
            }
        }

        var detailOpacity: Double {
            switch self {
            case .focused: 1
            case .side: 0.9
            }
        }

        var titleLineLimit: Int {
            switch self {
            case .focused: 2
            case .side: 3
            }
        }

        var contentPadding: CGFloat {
            switch self {
            case .focused: 16
            case .side: 14
            }
        }

        var progressScale: CGFloat {
            switch self {
            case .focused: 2.0
            case .side: 1.65
            }
        }
    }

    let course: Course
    let style: Style

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CourseArtwork(course: course)

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .black.opacity(0.22), location: 0.40),
                    .init(color: .black.opacity(0.82), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 10) {
                if !course.categories.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(course.categories.prefix(style == .focused ? 3 : 2)), id: \.rawValue) { cat in
                            HStack(spacing: 4) {
                                Image(systemName: cat.iconName)
                                Text(cat.displayName)
                            }
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.18), in: Capsule())
                        }
                    }
                }

                Text(course.title)
                    .font(style.titleFont)
                    .foregroundStyle(.white)
                    .lineLimit(style.titleLineLimit)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 1)

                HStack {
                    Text(L.PilgrimageHome.progressFormat(course.checkedInCount, course.totalSpotCount))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.84 * style.detailOpacity))
                    Spacer()
                    Text(course.isCompleted ? L.Course.completed : "\(Int(course.completionRate * 100))%")
                        .font(.caption.bold())
                        .foregroundStyle(course.isCompleted ? Color.green : .white)
                }

                ProgressView(value: course.completionRate)
                    .progressViewStyle(.linear)
                    .tint(course.isCompleted ? .green : .white)
                    .scaleEffect(y: style.progressScale, anchor: .center)
                    .environment(\.colorScheme, .dark)
            }
            .padding(style.contentPadding)
            .padding(.bottom, style == .focused ? 6 : 2)
        }
        .frame(height: style.cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1.1)
        }
        .shadow(color: .black.opacity(style == .focused ? 0.18 : 0.1), radius: style == .focused ? 18 : 10, x: 0, y: style == .focused ? 10 : 6)
    }
}

private struct CourseArtwork: View {
    let course: Course

    var body: some View {
        ZStack {
            if let urlStr = course.coverImageUrl, let url = URL(string: urlStr) {
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

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black.opacity(0.08), location: 0.45),
                    .init(color: .black.opacity(0.38), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .clipped()
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.indigo.opacity(0.85),
                    Color.cyan.opacity(0.68)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.white.opacity(0.14))
                .frame(width: 120, height: 120)
                .offset(x: -40, y: -24)

            Circle()
                .fill(.white.opacity(0.1))
                .frame(width: 92, height: 92)
                .offset(x: 72, y: 38)

            VStack(spacing: 8) {
                Image(systemName: course.isCompleted ? "checkmark.seal.fill" : (course.categories.first?.iconName ?? "map.fill"))
                    .font(.system(size: 34, weight: .bold))
                Text(course.categories.first.map { course.isCompleted ? L.Course.completed : $0.displayName } ?? "Pilgrimage")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(.white.opacity(0.92))
        }
    }
}

private struct SpotPanelHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.indigo.opacity(0.1))
                    .frame(width: 22, height: 22)
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.indigo)
            }

            Text(title)
                .font(.subheadline.weight(.bold))
                .tracking(0.2)
                .foregroundStyle(.primary)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
    }
}

// MARK: - ③ 近くのスポット行

private struct NearbySpotRow: View {
    let course: Course
    let spot: CourseSpot
    let distance: Double

    var body: some View {
        HStack(spacing: 12) {
            SpotPanelThumbnailView(course: course, spot: spot)

            VStack(alignment: .leading, spacing: 2) {
                Text(spot.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(course.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 2) {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                    Text(L.PilgrimageHome.distanceFormatted(distance))
                        .font(.caption2.bold().monospacedDigit())
                }
                .foregroundStyle(.indigo)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - ④ 最近の達成行

private struct RecentAchievementRow: View {
    let course: Course
    let spot: CourseSpot

    var body: some View {
        HStack(spacing: 12) {
            SpotPanelThumbnailView(course: course, spot: spot)

            VStack(alignment: .leading, spacing: 2) {
                Text(spot.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(course.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let date = spot.firstCheckedInAt {
                    HStack(spacing: 2) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - ③ お気に入りスポット行

private struct FavoriteSpotRow: View {
    let course: Course
    let spot: CourseSpot

    var body: some View {
        HStack(spacing: 12) {
            SpotPanelThumbnailView(course: course, spot: spot)

            VStack(alignment: .leading, spacing: 2) {
                Text(spot.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(course.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct SpotPanelThumbnailView: View {
    let course: Course
    let spot: CourseSpot

    var body: some View {
        Group {
            if let uiImage = spot.localCoverImagePath.flatMap({ LocalImageStorage.shared.load(from: $0) }) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let urlStr = spot.coverImageUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 96, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var placeholder: some View {
        ZStack {
            Color.indigo.opacity(0.1)
            Image(systemName: course.isCompleted ? "checkmark.seal.fill" : (course.categories.first?.iconName ?? "map"))
                .font(.title3)
                .foregroundStyle(.indigo.opacity(0.5))
        }
    }
}

struct SelectedCourseRoute: Identifiable, Hashable {
    let id: UUID
}

private enum PilgrimageMapBackgroundStyle {
    case organic
    case structured
}

private struct PilgrimageMapBackgroundConfig {
    let style: PilgrimageMapBackgroundStyle
    let seed: UInt64
    let lineWidth: CGFloat
    let blur: CGFloat
    let opacity: Double
    let exclusionRadiusFactor: CGFloat
    let padding: CGFloat
    let offset: CGSize
    let organicLineCount: Int
    let gridSpacing: CGFloat
    let gridJitter: CGFloat
    let gridStepMin: CGFloat
    let gridStepMax: CGFloat
    let diagonalChance: Double
    let diagonalBackChance: Double
    let diagonalStride: CGFloat
    let diagonalBackStride: CGFloat
}

private struct PilgrimageMapBackgroundLayer: View {
    let config: PilgrimageMapBackgroundConfig

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.38)
            let radius = min(size.width, size.height) * config.exclusionRadiusFactor
            let strokeColor = colorScheme == .dark ? Color.white : Color.black

            let shape: PilgrimageAnyShape = {
                switch config.style {
                case .organic:
                    return PilgrimageAnyShape(
                        PilgrimageAbstractMapLinesPath(
                            seed: config.seed,
                            lineCount: config.organicLineCount,
                            padding: config.padding,
                            exclusionCenter: center,
                            exclusionRadius: radius
                        )
                    )
                case .structured:
                    return PilgrimageAnyShape(
                        PilgrimageAbstractMapGridPath(
                            seed: config.seed,
                            spacing: config.gridSpacing,
                            jitter: config.gridJitter,
                            stepMin: config.gridStepMin,
                            stepMax: config.gridStepMax,
                            diagonalChance: config.diagonalChance,
                            diagonalBackChance: config.diagonalBackChance,
                            diagonalStride: config.diagonalStride,
                            diagonalBackStride: config.diagonalBackStride,
                            padding: config.padding,
                            exclusionCenter: center,
                            exclusionRadius: radius
                        )
                    )
                }
            }()

            shape.stroke(
                strokeColor,
                style: StrokeStyle(
                    lineWidth: config.lineWidth,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .offset(config.offset)
            .blur(radius: config.blur)
            .opacity(config.opacity)
        }
        .allowsHitTesting(false)
    }
}

private struct PilgrimageAbstractMapLinesPath: Shape {
    let seed: UInt64
    let lineCount: Int
    let padding: CGFloat
    let exclusionCenter: CGPoint
    let exclusionRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var rng = PilgrimageSeededRandom(state: seed)
        var path = Path()
        let bandCount = max(5, Int(sqrt(Double(lineCount))))
        for i in 0..<lineCount {
            var placed = false
            for _ in 0..<3 {
                let isHorizontal = rng.nextDouble() < 0.6
                let isCurved = rng.nextDouble() < 0.75
                let bandIndex = i % bandCount
                let (p0, p1, p2, c0, c1) = makeSmoothCurve(
                    in: rect,
                    horizontal: isHorizontal,
                    bandIndex: bandIndex,
                    bandCount: bandCount,
                    rng: &rng
                )
                let mid = midpoint(p0, p2)
                if isInsideExclusion(mid) {
                    continue
                }
                path.move(to: p0)
                if isCurved {
                    path.addQuadCurve(to: p1, control: c0)
                    path.addQuadCurve(to: p2, control: c1)
                } else {
                    path.addLine(to: p1)
                    path.addLine(to: p2)
                }
                placed = true
                break
            }
            if !placed {
                continue
            }
        }

        return path
    }

    private func makeSmoothCurve(
        in rect: CGRect,
        horizontal: Bool,
        bandIndex: Int,
        bandCount: Int,
        rng: inout PilgrimageSeededRandom
    ) -> (CGPoint, CGPoint, CGPoint, CGPoint, CGPoint) {
        let xMin = rect.minX + padding
        let xMax = rect.maxX - padding
        let yMin = rect.minY + padding
        let yMax = rect.maxY - padding
        let bandSizeY = (yMax - yMin) / CGFloat(bandCount)
        let bandSizeX = (xMax - xMin) / CGFloat(bandCount)

        if horizontal {
            let yBandMin = yMin + CGFloat(bandIndex) * bandSizeY
            let yBandMax = min(yBandMin + bandSizeY, yMax)
            let y = rng.nextCGFloat(in: yBandMin...yBandMax)
            let x0 = rng.nextCGFloat(in: xMin...xMax * 0.30)
            let x2 = rng.nextCGFloat(in: xMax * 0.70...xMax)
            let bend = rng.nextCGFloat(in: -28...28)
            let p0 = CGPoint(x: x0, y: y)
            let p2 = CGPoint(x: x2, y: y + bend)
            let p1 = CGPoint(
                x: lerp(x0, x2, t: 0.5) + rng.nextCGFloat(in: -10...10),
                y: y + rng.nextCGFloat(in: -8...8)
            )
            let c0 = CGPoint(
                x: lerp(x0, x2, t: 0.25),
                y: y + rng.nextCGFloat(in: -24...24)
            )
            let c1 = CGPoint(
                x: lerp(x0, x2, t: 0.75),
                y: y + bend + rng.nextCGFloat(in: -24...24)
            )
            return (p0, p1, p2, c0, c1)
        } else {
            let xBandMin = xMin + CGFloat(bandIndex) * bandSizeX
            let xBandMax = min(xBandMin + bandSizeX, xMax)
            let x = rng.nextCGFloat(in: xBandMin...xBandMax)
            let y0 = rng.nextCGFloat(in: yMin...yMax * 0.30)
            let y2 = rng.nextCGFloat(in: yMax * 0.70...yMax)
            let bend = rng.nextCGFloat(in: -28...28)
            let p0 = CGPoint(x: x, y: y0)
            let p2 = CGPoint(x: x + bend, y: y2)
            let p1 = CGPoint(
                x: x + rng.nextCGFloat(in: -8...8),
                y: lerp(y0, y2, t: 0.5) + rng.nextCGFloat(in: -10...10)
            )
            let c0 = CGPoint(
                x: x + rng.nextCGFloat(in: -24...24),
                y: lerp(y0, y2, t: 0.25)
            )
            let c1 = CGPoint(
                x: x + bend + rng.nextCGFloat(in: -24...24),
                y: lerp(y0, y2, t: 0.75)
            )
            return (p0, p1, p2, c0, c1)
        }
    }

    private func isInsideExclusion(_ point: CGPoint) -> Bool {
        let dx = point.x - exclusionCenter.x
        let dy = point.y - exclusionCenter.y
        return (dx * dx + dy * dy) < (exclusionRadius * exclusionRadius)
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    private func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) * 0.5, y: (a.y + b.y) * 0.5)
    }
}

private struct PilgrimageAbstractMapGridPath: Shape {
    let seed: UInt64
    let spacing: CGFloat
    let jitter: CGFloat
    let stepMin: CGFloat
    let stepMax: CGFloat
    let diagonalChance: Double
    let diagonalBackChance: Double
    let diagonalStride: CGFloat
    let diagonalBackStride: CGFloat
    let padding: CGFloat
    let exclusionCenter: CGPoint
    let exclusionRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var rng = PilgrimageSeededRandom(state: seed)
        var path = Path()
        let xMin = rect.minX + padding
        let xMax = rect.maxX - padding
        let yMin = rect.minY + padding
        let yMax = rect.maxY - padding

        var y = yMin
        while y <= yMax {
            let yJitter = rng.nextCGFloat(in: -jitter...jitter)
            let start = CGPoint(x: xMin, y: y + yJitter)
            let end = CGPoint(x: xMax, y: y + yJitter + rng.nextCGFloat(in: -jitter...jitter))
            if !isInsideExclusion(midpoint(start, end)) {
                path.move(to: start)
                path.addLine(to: end)
            }
            y += spacing * rng.nextCGFloat(in: stepMin...stepMax)
        }

        var x = xMin
        while x <= xMax {
            let xJitter = rng.nextCGFloat(in: -jitter...jitter)
            let start = CGPoint(x: x + xJitter, y: yMin)
            let end = CGPoint(x: x + xJitter + rng.nextCGFloat(in: -jitter...jitter), y: yMax)
            if !isInsideExclusion(midpoint(start, end)) {
                path.move(to: start)
                path.addLine(to: end)
            }
            x += spacing * rng.nextCGFloat(in: stepMin...stepMax)
        }

        var d = xMin
        while d <= xMax {
            if rng.nextDouble() < diagonalChance {
                let start = CGPoint(x: d, y: yMin)
                let end = CGPoint(x: d + (yMax - yMin), y: yMax)
                if !isInsideExclusion(midpoint(start, end)) {
                    path.move(to: start)
                    path.addLine(to: end)
                }
            }
            d += spacing * diagonalStride
        }

        var d2 = xMax
        while d2 >= xMin {
            if rng.nextDouble() < diagonalBackChance {
                let start = CGPoint(x: d2, y: yMin)
                let end = CGPoint(x: d2 - (yMax - yMin), y: yMax)
                if !isInsideExclusion(midpoint(start, end)) {
                    path.move(to: start)
                    path.addLine(to: end)
                }
            }
            d2 -= spacing * diagonalBackStride
        }

        return path
    }

    private func isInsideExclusion(_ point: CGPoint) -> Bool {
        let dx = point.x - exclusionCenter.x
        let dy = point.y - exclusionCenter.y
        return (dx * dx + dy * dy) < (exclusionRadius * exclusionRadius)
    }

    private func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) * 0.5, y: (a.y + b.y) * 0.5)
    }
}

private struct PilgrimageAnyShape: Shape, @unchecked Sendable {
    private let _path: @Sendable (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        _path = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}

private struct PilgrimageSeededRandom {
    var state: UInt64

    mutating func next() -> UInt64 {
        state = 2862933555777941757 &* state &+ 3037000493
        return state
    }

    mutating func nextDouble() -> Double {
        Double(next() % 1_000_000) / 1_000_000
    }

    mutating func nextCGFloat(in range: ClosedRange<CGFloat>) -> CGFloat {
        let t = CGFloat(nextDouble())
        return range.lowerBound + (range.upperBound - range.lowerBound) * t
    }
}

// MARK: - ナビゲーションルート

enum PilgrimageHomeRoute: Hashable {
    case courseList
    /// コース詳細（指定スポットをフォーカス）
    case courseDetail(courseId: UUID, spotId: UUID)
    /// コース詳細（スポット未指定、サマリーを表示）
    case courseDetailSummary(courseId: UUID)
    /// スポット情報パネルの一覧画面
    case spotPanelList(kind: SpotPanelKind)
}
