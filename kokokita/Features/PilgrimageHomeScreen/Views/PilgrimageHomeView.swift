import SwiftUI
import CoreLocation

// 巡礼モードのホーム画面（設計書 6.2 実装版）
// isPresented と値ベースナビゲーションの混在を避けるため、
// NavigationLink(value:) で統一する
struct PilgrimageHomeView: View {
    @State private var store = CourseListStore()
    @State private var userLocation: CLLocation? = CLLocationManager().location
    @State private var isRefreshingNearbySpots = false

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
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.walk")
                            .foregroundStyle(.indigo)
                        Text(L.PilgrimageHome.navTitle)
                            .font(.headline)
                    }
                }
            }
            .task {
                await store.load()
                userLocation = CLLocationManager().location
            }
            .onReceive(NotificationCenter.default.publisher(for: .courseChanged)) { _ in
                Task { await store.load() }
                userLocation = CLLocationManager().location
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
            .navigationDestination(for: UUID.self) { courseId in
                if let course = store.courses.first(where: { $0.id == courseId }) {
                    CourseDetailView(course: course)
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
                // ① ヒーローカード
                if let top = topCourse {
                    NavigationLink(value: top.id) {
                        HeroCard(course: top)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 28)
                }

                // ② コース一覧（横スクロール）
                courseScrollSection
                    .padding(.bottom, 28)

                // ③ 近くのスポット
                nearbySection
                    .padding(.bottom, 28)

                // ④ 最近の達成
                recentSection
                    .padding(.bottom, 32)
            }
        }
    }

    // MARK: - ② コース横スクロール

    private var courseScrollSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L.PilgrimageHome.coursesTitle)
                    .font(.headline)
                    .padding(.leading, 16)
                Spacer()
                NavigationLink(value: PilgrimageHomeRoute.courseList) {
                    Text(L.PilgrimageHome.seeAll)
                        .font(.subheadline)
                        .foregroundStyle(.indigo)
                }
                .padding(.trailing, 16)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(store.courses) { course in
                        NavigationLink(value: course.id) {
                            CourseCard(course: course)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
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
                    ZStack {
                        Circle()
                            .fill(.regularMaterial)
                            .frame(width: 32, height: 32)

                        if isRefreshingNearbySpots {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.indigo)
                        }
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
                    .padding(.leading, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentAchievements.enumerated()), id: \.element.spot.id) { index, item in
                        NavigationLink(value: PilgrimageHomeRoute.courseDetail(courseId: item.course.id, spotId: item.spot.id)) {
                            RecentAchievementRow(course: item.course, spot: item.spot)
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
        defer { isRefreshingNearbySpots = false }

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
    }
}

// MARK: - ① ヒーローカード

private struct HeroCard: View {
    let course: Course

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // カバー画像（フル幅でどんと表示）
            if let urlStr = course.coverImageUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .clipped()
                    case .empty:
                        Color.indigo.opacity(0.08).frame(height: 180)
                    default:
                        EmptyView()
                    }
                }
            }

            // テキストコンテンツ
            VStack(alignment: .leading, spacing: 12) {
                // コース名
                Text(course.title)
                    .font(.title3.bold())
                    .lineLimit(2)

                // カテゴリタグ（コース一覧と同デザイン）
                if !course.categories.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(course.categories, id: \.rawValue) { cat in
                            HStack(spacing: 3) {
                                Image(systemName: cat.iconName)
                                Text(cat.displayName)
                            }
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.indigo)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.indigo.opacity(0.1), in: Capsule())
                        }
                    }
                }

                // 進捗テキスト
                HStack {
                    Text(L.PilgrimageHome.progressFormat(course.checkedInCount, course.totalSpotCount))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(course.completionRate * 100))%")
                        .font(.subheadline.bold())
                        .foregroundStyle(course.isCompleted ? .green : .indigo)
                }

                // プログレスバー（大）
                ProgressView(value: course.completionRate)
                    .progressViewStyle(.linear)
                    .tint(course.isCompleted ? .green : .indigo)
                    .scaleEffect(y: 1.8, anchor: .center)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}

// MARK: - ② コースカード（横スクロール用）

private struct CourseCard: View {
    let course: Course

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // カバー画像エリア（リモート画像 or カテゴリアイコンフォールバック）
            Group {
                if let urlStr = course.coverImageUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 80)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        default:
                            courseIconPlaceholder
                        }
                    }
                } else {
                    courseIconPlaceholder
                }
            }
            .frame(height: 80)

            VStack(alignment: .leading, spacing: 4) {
                // コース名
                Text(course.title)
                    .font(.subheadline.bold())
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                // 達成数
                Text("\(course.checkedInCount)/\(course.totalSpotCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 2)
        }
        .frame(width: 140)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        )
    }

    // カテゴリアイコンのプレースホルダー
    private var courseIconPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.indigo.opacity(0.12))
            VStack(spacing: 4) {
                Image(systemName: course.isCompleted ? "checkmark.seal.fill" : (course.categories.first?.iconName ?? "map"))
                    .font(.title2)
                    .foregroundStyle(.indigo.opacity(0.6))
                if let cat = course.categories.first {
                    Text(course.isCompleted ? L.Course.completed : cat.displayName)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.indigo.opacity(0.6))
                }
            }
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

// MARK: - ナビゲーションルート

private enum PilgrimageHomeRoute: Hashable {
    case courseList
    /// コース詳細（指定スポットをフォーカス）
    case courseDetail(courseId: UUID, spotId: UUID)
}
