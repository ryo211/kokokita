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

    // MARK: - Derived Data

    /// 全コース中で最も達成率が高いコース（ヒーロー表示用）
    private var topCourse: Course? {
        store.courses.max(by: { $0.completionRate < $1.completionRate })
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
            Group {
                if store.courses.isEmpty {
                    emptyCoursesView
                } else {
                    mainContent
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
            // コース一覧・コース詳細（スポット指定）への遷移
            .navigationDestination(for: PilgrimageHomeRoute.self) { route in
                switch route {
                case .courseList:
                    CourseListView(store: store)
                case .courseDetail(let courseId, let spotId):
                    if let course = store.courses.first(where: { $0.id == courseId }) {
                        CourseDetailView(course: course, initialSelectedSpotId: spotId)
                    }
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

                // ② 近くのスポット
                nearbySection
                    .padding(.bottom, 28)

                // ③ 最近の達成
                recentSection
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

    // MARK: - ③ 近くのスポット

    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(L.PilgrimageHome.nearbyTitle)
                    .font(.headline)

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

                Spacer()
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
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - ④ 最近の達成

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.PilgrimageHome.recentTitle)
                .font(.headline)
                .padding(.leading, 16)

            if recentAchievements.isEmpty {
                Text(L.PilgrimageHome.noRecentAchievements)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 16)
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
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 16)
            }
        }
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
            let centerCardWidth = min(width * 0.68, 320)
            let cardSpacing = centerCardWidth * 0.72

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
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .highPriorityGesture(carouselGesture(cardSpacing: cardSpacing))
            .animation(.spring(response: 0.36, dampingFraction: 0.82), value: selectedIndex)
            .animation(.spring(response: 0.28, dampingFraction: 0.88), value: dragOffset)
        }
        .frame(height: 310)
        .padding(.top, 4)
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
        12 + min(abs(progress), 1.8) * 26
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
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.indigo.opacity(0.16),
                            Color.cyan.opacity(0.08),
                            Color.white.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.65), lineWidth: 1.2)

            Circle()
                .fill(Color.indigo.opacity(0.14))
                .frame(width: 180, height: 180)
                .offset(x: -120, y: -80)

            Circle()
                .fill(Color.cyan.opacity(0.11))
                .frame(width: 140, height: 140)
                .offset(x: 130, y: 90)
        }
        .shadow(color: .indigo.opacity(0.08), radius: 18, x: 0, y: 8)
    }
}

private struct CourseCarouselCard: View {
    enum Style: Equatable {
        case focused
        case side

        var cardHeight: CGFloat {
            switch self {
            case .focused: 236
            case .side: 210
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
            case .focused: 18
            case .side: 16
            }
        }

        var progressScale: CGFloat {
            switch self {
            case .focused: 2.2
            case .side: 1.8
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

// MARK: - ③ 近くのスポット行

private struct NearbySpotRow: View {
    let course: Course
    let spot: CourseSpot
    let distance: Double

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .foregroundStyle(.indigo)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(spot.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(course.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(L.PilgrimageHome.distanceFormatted(distance))
                .font(.caption.bold())
                .foregroundStyle(.indigo)
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
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.indigo)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(spot.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(course.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let date = spot.firstCheckedInAt {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct SelectedCourseRoute: Identifiable, Hashable {
    let id: UUID
}

// MARK: - ナビゲーションルート

private enum PilgrimageHomeRoute: Hashable {
    case courseList
    /// コース詳細（指定スポットをフォーカス）
    case courseDetail(courseId: UUID, spotId: UUID)
}
