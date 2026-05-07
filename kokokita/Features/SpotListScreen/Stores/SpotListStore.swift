import Foundation
import Observation
import CoreLocation

// スポット一覧画面の状態管理
// 有効な巡礼コースに含まれるスポットを、任意の選択地点から近い順に提供する
@MainActor
@Observable
final class SpotListStore {

    // MARK: - 状態

    /// 選択地点（nil の場合は現在地を取得中）
    var selectedCoordinate: CLLocationCoordinate2D?
    /// 選択地点の名称（場所検索で選択した場合に設定）
    var selectedLocationName: String?
    /// 近い順のスポット一覧（course・spot・距離のタプル）
    var nearbySpots: [(course: Course, spot: CourseSpot, distance: Double)] = []
    /// 表示件数（後続機能の件数設定・絞り込みで拡張予定）
    var displayLimit: Int = 10
    /// フィルターで除外するコースID（空 = すべて表示）
    var excludedCourseIds: Set<UUID> = []
    /// お気に入りスポットのみ表示
    var favoritesOnly: Bool = false
    /// お気に入りID（View から同期）
    var favoriteSpotIds: Set<UUID> = []
    var isLoading = false
    var errorMessage: String?

    // MARK: - 内部

    private var courses: [Course] = []

    /// フィルターパネル用: 全有効コース一覧
    var allCourses: [Course] { courses }

    /// フィルター適用後の表示対象スポット総数（距離制限なし）
    var totalFilteredSpotCount: Int {
        allCourses
            .filter { !excludedCourseIds.contains($0.id) && (!$0.isUserCreated || $0.isEnabled) }
            .flatMap { $0.spots.filter { $0.hasValidCoordinate } }
            .count
    }
    private let repo: CourseRepository
    private var observers: [NSObjectProtocol] = []

    init(repo: CourseRepository = AppContainer.shared.courseRepo) {
        self.repo = repo

        // コース変更（チェックイン・ダウンロード等）を監視して一覧を再計算
        let observer = NotificationCenter.default.addObserver(
            forName: .courseChanged, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                await self?.reloadCourses()
            }
        }
        observers = [observer]
    }

    // MARK: - ロード

    func load() async {
        isLoading = true
        defer { isLoading = false }

        // デフォルトの選択地点として現在地を設定
        if selectedCoordinate == nil {
            selectedCoordinate = CLLocationManager().location?.coordinate
        }
        await reloadCourses()
    }

    private func reloadCourses() async {
        do {
            let all = try repo.fetchAll()
            // バンドルコースはすべて対象、自作コースは有効/無効問わずすべて含める
            // （スポット計算時に isEnabled == false の自作コースは除外する）
            courses = all
            recalculateNearbySpots()
        } catch {
            Logger.error("SpotListStore: コース読み込みエラー", error: error)
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 距離計算

    /// 選択地点からの距離を計算してスポット一覧を更新する
    func recalculateNearbySpots() {
        guard let coord = selectedCoordinate else {
            nearbySpots = []
            return
        }
        let fromLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        var results: [(course: Course, spot: CourseSpot, distance: Double)] = []
        for course in courses
            where !excludedCourseIds.contains(course.id)
               && (!course.isUserCreated || course.isEnabled) {
            for spot in course.spots where spot.hasValidCoordinate
                                       && (!favoritesOnly || favoriteSpotIds.contains(spot.id)) {
                let spotLocation = CLLocation(latitude: spot.latitude, longitude: spot.longitude)
                results.append((course, spot, fromLocation.distance(from: spotLocation)))
            }
        }
        nearbySpots = Array(results.sorted { $0.distance < $1.distance }.prefix(displayLimit))
    }

    // MARK: - 地点選択

    /// 地図タップまたは場所検索からの地点選択
    func updateSelectedLocation(_ coordinate: CLLocationCoordinate2D, name: String? = nil) {
        selectedCoordinate = coordinate
        selectedLocationName = name
        recalculateNearbySpots()
    }
}
