import Foundation
import Observation
import CoreLocation

// スポット一覧の表示モード
enum SpotListMode: CaseIterable, Hashable {
    case nearby      // 近くのスポット（有効コースの全スポット・距離順）
    case favorites   // お気に入りスポット
    case visited     // 行ったスポット（達成済み）
    case prefecture  // 都道府県別スポット
    case folder      // フォルダ内スポット

    var title: String {
        switch self {
        case .nearby:      return L.SpotList.modeNearby
        case .favorites:   return L.SpotList.modeFavorites
        case .visited:     return L.SpotList.modeVisited
        case .prefecture:  return L.SpotList.modePrefecture
        case .folder:      return L.SpotList.modeFolder
        }
    }

    var shortTitle: String {
        switch self {
        case .nearby:      return L.SpotList.modeNearbyShort
        case .favorites:   return L.SpotList.modeFavoritesShort
        case .visited:     return L.SpotList.modeVisitedShort
        case .prefecture:  return L.SpotList.modePrefectureShort
        case .folder:      return L.SpotList.modeFolderShort
        }
    }

    var systemImage: String {
        switch self {
        case .nearby:      return "location.north.line.fill"
        case .favorites:   return "heart.fill"
        case .visited:     return "checkmark.seal.fill"
        case .prefecture:  return "map.fill"
        case .folder:      return "folder.fill"
        }
    }
}

// お気に入り・行ったモード用のソートタイプ
enum SpotListSortType: Hashable {
    case added    // 追加順
    case distance // 近い順
}

// スポット一覧画面の状態管理
// 有効な巡礼コースに含まれるスポットを、選択モード・ソートに応じて提供する
@MainActor
@Observable
final class SpotListStore {

    // MARK: - 状態

    /// 表示モード
    var listMode: SpotListMode = .nearby
    /// ソートタイプ（お気に入り・行ったモード用）
    var sortType: SpotListSortType = .added
    /// 選択地点（nil の場合は現在地を取得中）
    var selectedCoordinate: CLLocationCoordinate2D?
    /// 選択地点の名称（場所検索で選択した場合に設定）
    var selectedLocationName: String?
    /// 表示スポット一覧（course・spot・距離のタプル）
    var nearbySpots: [(course: Course, spot: CourseSpot, distance: Double)] = []
    /// 表示件数（近くのスポットモード用）
    var displayLimit: Int = 10
    /// フィルターで除外するコースID（空 = すべて表示）
    var excludedCourseIds: Set<UUID> = []
    /// 都道府県別モードで選択中の都道府県（デフォルト: 東京都）
    var selectedPrefecture: String = "東京都"
    /// 都道府県別モードの現在ページ（1始まり）
    var prefecturePage: Int = 1
    /// 都道府県別モードの1ページあたりの件数
    let prefecturePageSize: Int = 50
    /// 都道府県別モードのスポット総件数（ページネーション用）
    private(set) var prefectureTotalCount: Int = 0
    /// お気に入りID（View から同期）
    var favoriteSpotIds: Set<UUID> = []
    /// フォルダ内スポットID（View から同期、順序保持）
    var folderSpotIds: [UUID] = []
    var isLoading = false
    var errorMessage: String?

    // MARK: - 内部

    private var courses: [Course] = []

    /// フィルターパネル用: 現在のモードに関連するコース一覧
    var relevantCourses: [Course] {
        let active = courses.filter { !$0.isUserCreated || $0.isEnabled }
        switch listMode {
        case .nearby:
            return active
        case .favorites:
            return active.filter { course in
                course.spots.contains { favoriteSpotIds.contains($0.id) }
            }
        case .visited:
            return active.filter { course in
                course.spots.contains { $0.isCheckedIn }
            }
        case .prefecture:
            return active.filter { course in
                course.spots.contains { Self.extractPrefecture(from: $0.address) == selectedPrefecture }
            }
        case .folder:
            return active.filter { course in
                course.spots.contains { folderSpotIds.contains($0.id) }
            }
        }
    }

    /// フィルター適用後の表示対象スポット総数（絞り込みパネルの件数表示用）
    var totalFilteredSpotCount: Int {
        relevantCourses
            .filter { !excludedCourseIds.contains($0.id) }
            .flatMap { course -> [CourseSpot] in
                let valid = course.spots.filter { $0.hasValidCoordinate }
                switch listMode {
                case .nearby:      return valid
                case .favorites:   return valid.filter { favoriteSpotIds.contains($0.id) }
                case .visited:     return valid.filter { $0.isCheckedIn }
                case .prefecture:  return valid.filter { Self.extractPrefecture(from: $0.address) == selectedPrefecture }
                case .folder:      return valid.filter { folderSpotIds.contains($0.id) }
                }
            }
            .count
    }

    /// 都道府県別モードの総ページ数
    var prefecturePageCount: Int {
        max(1, Int(ceil(Double(prefectureTotalCount) / Double(prefecturePageSize))))
    }

    /// 都道府県ごとのスポット件数（ドロップダウン表示用）
    /// 有効コースの全スポットを一度走査するだけなので軽量
    var prefectureSpotCounts: [String: Int] {
        let active = courses.filter { !$0.isUserCreated || $0.isEnabled }
        var counts: [String: Int] = [:]
        for course in active {
            for spot in course.spots where spot.hasValidCoordinate {
                guard let pref = Self.extractPrefecture(from: spot.address) else { continue }
                counts[pref, default: 0] += 1
            }
        }
        return counts
    }

    // MARK: - 都道府県ユーティリティ

    static let prefectureList: [String] = [
        "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
        "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
        "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県", "岐阜県",
        "静岡県", "愛知県", "三重県", "滋賀県", "京都府", "大阪府", "兵庫県",
        "奈良県", "和歌山県", "鳥取県", "島根県", "岡山県", "広島県", "山口県",
        "徳島県", "香川県", "愛媛県", "高知県", "福岡県", "佐賀県", "長崎県",
        "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県"
    ]

    static func extractPrefecture(from address: String?) -> String? {
        guard let address else { return nil }
        return prefectureList.first { address.contains($0) }
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
            courses = all
            recalculateNearbySpots()
        } catch {
            Logger.error("SpotListStore: コース読み込みエラー", error: error)
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - スポット計算（モード・ソート対応）

    func recalculateNearbySpots() {
        switch listMode {
        case .nearby:
            recalculateNearby()
        case .favorites:
            recalculateFavorites()
        case .visited:
            recalculateVisited()
        case .prefecture:
            recalculatePrefecture()
        case .folder:
            recalculateFolder()
        }
    }

    /// 近くのスポットモード: 有効コースの全スポットを距離昇順、表示件数で制限
    private func recalculateNearby() {
        guard let coord = selectedCoordinate else {
            nearbySpots = []
            return
        }
        let fromLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        var results: [(course: Course, spot: CourseSpot, distance: Double)] = []
        for course in courses
            where !excludedCourseIds.contains(course.id)
               && (!course.isUserCreated || course.isEnabled) {
            for spot in course.spots where spot.hasValidCoordinate {
                let spotLocation = CLLocation(latitude: spot.latitude, longitude: spot.longitude)
                results.append((course, spot, fromLocation.distance(from: spotLocation)))
            }
        }
        nearbySpots = Array(results.sorted { $0.distance < $1.distance }.prefix(displayLimit))
    }

    /// お気に入りモード: お気に入りスポットを追加順または距離順で全件表示
    private func recalculateFavorites() {
        let fromLocation = selectedCoordinate.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        var results: [(course: Course, spot: CourseSpot, distance: Double)] = []

        for course in courses where !excludedCourseIds.contains(course.id) && (!course.isUserCreated || course.isEnabled) {
            for spot in course.spots where spot.hasValidCoordinate && favoriteSpotIds.contains(spot.id) {
                let distance = fromLocation.map {
                    CLLocation(latitude: spot.latitude, longitude: spot.longitude).distance(from: $0)
                } ?? 0
                results.append((course, spot, distance))
            }
        }

        switch sortType {
        case .added:
            nearbySpots = results
        case .distance:
            nearbySpots = results.sorted { $0.distance < $1.distance }
        }
    }

    /// フォルダモード: フォルダ内スポットを登録順（folderSpotIds の順序）で全件表示
    private func recalculateFolder() {
        let fromLocation = selectedCoordinate.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        var spotMap: [UUID: (course: Course, spot: CourseSpot)] = [:]

        for course in courses where !excludedCourseIds.contains(course.id) && (!course.isUserCreated || course.isEnabled) {
            for spot in course.spots where spot.hasValidCoordinate && folderSpotIds.contains(spot.id) {
                spotMap[spot.id] = (course, spot)
            }
        }

        // folderSpotIds の登録順を維持しつつ結果を構築
        var results: [(course: Course, spot: CourseSpot, distance: Double)] = []
        for spotId in folderSpotIds {
            guard let entry = spotMap[spotId] else { continue }
            let distance = fromLocation.map {
                CLLocation(latitude: entry.spot.latitude, longitude: entry.spot.longitude).distance(from: $0)
            } ?? 0
            results.append((entry.course, entry.spot, distance))
        }

        nearbySpots = results
    }

    /// 行ったスポットモード: 達成済みスポットを追加順（チェックイン日時降順）または距離順で全件表示
    private func recalculateVisited() {
        let fromLocation = selectedCoordinate.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        var results: [(course: Course, spot: CourseSpot, distance: Double)] = []

        for course in courses where !excludedCourseIds.contains(course.id) && (!course.isUserCreated || course.isEnabled) {
            for spot in course.spots where spot.hasValidCoordinate && spot.isCheckedIn {
                let distance = fromLocation.map {
                    CLLocation(latitude: spot.latitude, longitude: spot.longitude).distance(from: $0)
                } ?? 0
                results.append((course, spot, distance))
            }
        }

        switch sortType {
        case .added:
            // チェックイン日時の降順（最近行ったスポットを上に）
            nearbySpots = results.sorted {
                ($0.spot.firstCheckedInAt ?? .distantPast) > ($1.spot.firstCheckedInAt ?? .distantPast)
            }
        case .distance:
            nearbySpots = results.sorted { $0.distance < $1.distance }
        }
    }

    /// 都道府県別モード: 選択した都道府県のスポットを50件ページネーションで表示
    private func recalculatePrefecture() {
        let active = courses.filter { !$0.isUserCreated || $0.isEnabled }
        var results: [(course: Course, spot: CourseSpot, distance: Double)] = []
        for course in active where !excludedCourseIds.contains(course.id) {
            for spot in course.spots where spot.hasValidCoordinate {
                guard Self.extractPrefecture(from: spot.address) == selectedPrefecture else { continue }
                results.append((course, spot, 0))
            }
        }
        prefectureTotalCount = results.count
        let startIndex = (prefecturePage - 1) * prefecturePageSize
        let endIndex = min(startIndex + prefecturePageSize, results.count)
        nearbySpots = startIndex < results.count ? Array(results[startIndex..<endIndex]) : []
    }

    // MARK: - 地点選択

    /// 地図タップまたは場所検索からの地点選択
    func updateSelectedLocation(_ coordinate: CLLocationCoordinate2D, name: String? = nil) {
        selectedCoordinate = coordinate
        selectedLocationName = name
        recalculateNearbySpots()
    }
}
