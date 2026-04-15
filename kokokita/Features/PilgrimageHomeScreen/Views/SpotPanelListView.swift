import SwiftUI
import CoreLocation

// スポット情報パネルの種別
enum SpotPanelKind: Hashable {
    case nearby
    case recentAchievements
    case favorites

    var title: String {
        switch self {
        case .nearby: L.PilgrimageHome.nearbyTitle
        case .recentAchievements: L.PilgrimageHome.recentTitle
        case .favorites: L.SpotPanelList.favoritesTitle
        }
    }

    var systemImage: String {
        switch self {
        case .nearby: "location.north.line.fill"
        case .recentAchievements: "checkmark.seal.fill"
        case .favorites: "heart.fill"
        }
    }
}

// スポット行の付加情報（種別に応じて距離または日付を表示）
// 将来: case rating(Int) など追加予定
enum SpotPanelExtraInfo {
    case distance(Double)
    case date(Date?)
}

// スポット情報パネルリスト画面
// ホームの「近くのスポット」「最近行ったスポット」等のタイトルタップで遷移する一覧画面
struct SpotPanelListView: View {
    let kind: SpotPanelKind
    let store: CourseListStore
    let userLocation: CLLocation?

    @State private var sortByDistance = false
    @State private var displayLimit: Int = 10
    @State private var refreshedUserLocation: CLLocation? = nil
    @State private var isRefreshingNearbySpots = false

    // 0 = 全件表示
    private let displayLimitOptions: [Int] = [5, 10, 20, 50, 0]

    @Environment(\.spotFavoriteStore) private var favoriteStore

    private var effectiveUserLocation: CLLocation? {
        refreshedUserLocation ?? userLocation
    }

    // MARK: - 全スポット計算

    private var allSpots: [(course: Course, spot: CourseSpot, extraInfo: SpotPanelExtraInfo)] {
        switch kind {
        case .nearby:
            return nearbyAllSpots
        case .recentAchievements:
            return recentAllSpots
        case .favorites:
            return favoritesAllSpots
        }
    }

    // 未達成スポットを距離昇順で全件返す
    private var nearbyAllSpots: [(course: Course, spot: CourseSpot, extraInfo: SpotPanelExtraInfo)] {
        guard let location = effectiveUserLocation else { return [] }
        var results: [(course: Course, spot: CourseSpot, distance: Double)] = []
        for course in store.courses {
            for spot in course.spots where !spot.isCheckedIn {
                let spotLoc = CLLocation(latitude: spot.latitude, longitude: spot.longitude)
                results.append((course, spot, location.distance(from: spotLoc)))
            }
        }
        results.sort { $0.distance < $1.distance }
        return results.map { (course: $0.course, spot: $0.spot, extraInfo: .distance($0.distance)) }
    }

    // 達成済みスポットをデフォルト（日付降順）または距離昇順で全件返す
    private var recentAllSpots: [(course: Course, spot: CourseSpot, extraInfo: SpotPanelExtraInfo)] {
        var results: [(course: Course, spot: CourseSpot, date: Date?)] = []
        for course in store.courses {
            for spot in course.spots where spot.isCheckedIn {
                results.append((course, spot, spot.firstCheckedInAt))
            }
        }
        if sortByDistance, let location = effectiveUserLocation {
            results.sort { a, b in
                let da = CLLocation(latitude: a.spot.latitude, longitude: a.spot.longitude).distance(from: location)
                let db = CLLocation(latitude: b.spot.latitude, longitude: b.spot.longitude).distance(from: location)
                return da < db
            }
        } else {
            results.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        }
        return results.map { (course: $0.course, spot: $0.spot, extraInfo: .date($0.date)) }
    }

    // お気に入りスポット（登録順、距離ソート切り替え可）
    private var favoritesAllSpots: [(course: Course, spot: CourseSpot, extraInfo: SpotPanelExtraInfo)] {
        var results: [(course: Course, spot: CourseSpot)] = []
        for course in store.courses {
            for spot in course.spots where favoriteStore.isFavorite(spot.id) {
                results.append((course, spot))
            }
        }
        if sortByDistance, let location = effectiveUserLocation {
            results.sort { a, b in
                let da = CLLocation(latitude: a.spot.latitude, longitude: a.spot.longitude).distance(from: location)
                let db = CLLocation(latitude: b.spot.latitude, longitude: b.spot.longitude).distance(from: location)
                return da < db
            }
        }
        if let location = effectiveUserLocation {
            return results.map { item in
                let d = CLLocation(latitude: item.spot.latitude, longitude: item.spot.longitude).distance(from: location)
                return (course: item.course, spot: item.spot, extraInfo: .distance(d))
            }
        }
        return results.map { (course: $0.course, spot: $0.spot, extraInfo: .date(nil)) }
    }

    // 表示件数で絞り込んだリスト（displayLimit == 0 は全件）
    private var displayedSpots: [(course: Course, spot: CourseSpot, extraInfo: SpotPanelExtraInfo)] {
        guard displayLimit > 0 else { return allSpots }
        return Array(allSpots.prefix(displayLimit))
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            sortHeaderRow
            Divider()
            if displayedSpots.isEmpty {
                emptyView
            } else {
                spotList
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.indigo.opacity(0.1))
                            .frame(width: 22, height: 22)
                        Image(systemName: kind.systemImage)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.indigo)
                    }

                    Text(kind.title)
                        .font(.subheadline.weight(.bold))
                        .tracking(0.2)
                        .foregroundStyle(.primary)
                }
            }
        }
    }

    // MARK: - ソートヘッダー（右端に表示件数ピッカー）

    private var sortHeaderRow: some View {
        HStack(spacing: 8) {
            if kind == .nearby {
                Button {
                    Task { await refreshNearbySpots() }
                } label: {
                    HStack(spacing: 6) {
                        if isRefreshingNearbySpots {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        Text(L.PilgrimageHome.nearbyRefresh)
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.indigo)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.indigo.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isRefreshingNearbySpots)
                .accessibilityLabel("近くのスポットを更新")
            }

            // nearby は常に距離ソートのみのためソートチップ非表示
            // favorites と recentAchievements はデフォルト/距離ソート切り替え可
            if kind == .recentAchievements || kind == .favorites {
                SpotPanelSortChip(label: L.Course.sortDefault, isSelected: !sortByDistance) {
                    sortByDistance = false
                }
                SpotPanelSortChip(label: L.Course.sortDistance, isSelected: sortByDistance) {
                    sortByDistance = true
                }
                .disabled(userLocation == nil)
                .opacity(userLocation == nil ? 0.4 : 1)
            }

            Spacer()

            // 表示件数ピッカー
            Menu {
                ForEach(displayLimitOptions, id: \.self) { limit in
                    Button {
                        displayLimit = limit
                    } label: {
                        let label = limit == 0
                            ? L.SpotPanelList.displayLimitAll
                            : "\(limit)\(L.SpotPanelList.displayLimitSuffix)"
                        HStack {
                            Text(label)
                            if displayLimit == limit {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(
                        displayLimit == 0
                            ? L.SpotPanelList.displayLimitAll
                            : "\(displayLimit)\(L.SpotPanelList.displayLimitSuffix)"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.indigo)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.indigo)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.indigo.opacity(0.08), in: Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @MainActor
    private func refreshNearbySpots() async {
        guard kind == .nearby, !isRefreshingNearbySpots else { return }
        isRefreshingNearbySpots = true

        defer { isRefreshingNearbySpots = false }

        do {
            let locationService = DefaultLocationService()
            let (location, _) = try await locationService.requestOneShotLocation(
                accuracy: kCLLocationAccuracyHundredMeters,
                timeout: 8.0
            )
            refreshedUserLocation = location
        } catch {
            Logger.warning("Failed to refresh nearby spots list location: \(error.localizedDescription)")
        }
    }

    // MARK: - スポットリスト

    private var spotList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(displayedSpots.enumerated()), id: \.element.spot.id) { index, item in
                    NavigationLink(
                        value: PilgrimageHomeRoute.courseDetail(
                            courseId: item.course.id,
                            spotId: item.spot.id
                        )
                    ) {
                        SpotPanelListRow(
                            course: item.course,
                            spot: item.spot,
                            extraInfo: item.extraInfo
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if index < displayedSpots.count - 1 {
                        Divider().padding(.leading, 16)
                    }
                }
            }
        }
    }

    // MARK: - 空状態

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: kind.systemImage)
                .font(.system(size: 44))
                .foregroundStyle(.indigo.opacity(0.35))
            Text(emptyMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyMessage: String {
        switch kind {
        case .nearby: L.PilgrimageHome.noNearbySpots
        case .recentAchievements: L.PilgrimageHome.noRecentAchievements
        case .favorites: L.SpotPanelList.noFavorites
        }
    }
}

// MARK: - スポット行コンポーネント

private struct SpotPanelListRow: View {
    let course: Course
    let spot: CourseSpot
    let extraInfo: SpotPanelExtraInfo

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SpotPanelListThumbnailView(course: course, spot: spot)

            VStack(alignment: .leading, spacing: 4) {
                NavigationLink(value: PilgrimageHomeRoute.courseDetailSummary(courseId: course.id)) {
                    HStack(spacing: 4) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 10))
                        Text(course.title)
                            .font(.caption)
                            .lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(.indigo.opacity(0.75))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(spot.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    switch extraInfo {
                    case .distance(let d):
                        HStack(spacing: 2) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                            Text(L.PilgrimageHome.distanceFormatted(d))
                                .font(.caption2.bold().monospacedDigit())
                        }
                        .foregroundStyle(.secondary)
                    case .date(let date):
                        if let date {
                            HStack(spacing: 2) {
                                Image(systemName: "calendar")
                                    .font(.caption2)
                                Text(date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption2)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct SpotPanelListThumbnailView: View {
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

// MARK: - ソートチップ（SpotPanelListView 専用）

private struct SpotPanelSortChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    isSelected
                        ? AnyShapeStyle(Color.indigo)
                        : AnyShapeStyle(Color.secondary.opacity(0.12)),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
