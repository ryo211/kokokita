import Foundation
import Observation

// ダウンロード状態フィルター
enum StoreDownloadFilter: CaseIterable {
    case newArrivals
    case available
    case installed
    case all

    var label: String {
        switch self {
        case .newArrivals: L.CourseStore.filterNew
        case .available:   L.CourseStore.filterAvailable
        case .installed:   L.CourseStore.filterInstalled
        case .all:         L.CourseStore.filterAll
        }
    }
}

// コースストアシートの状態管理
@MainActor
@Observable
final class CourseStoreSheetStore {
    var storeCourses: [StoreCourseSummary] = []
    var downloadStatuses: [String: CourseDownloadStatus] = [:]
    var selectedCategory: CourseCategory? = nil
    var selectedDownloadFilter: StoreDownloadFilter = .available
    var searchText: String = ""
    var isLoadingIndex: Bool = false
    /// ロード済みフラグ（CourseListView からの pre-fetch と二重取得防止）
    private(set) var isIndexLoaded = false
    var showError: Bool = false
    var errorMessage: String?

    private static let lastVisitedKey = "courseStore.lastVisitedAt"

    /// ストアを最後に閲覧した日時（UserDefaults に永続化）
    private(set) var lastVisitedStoreAt: Date = {
        (UserDefaults.standard.object(forKey: lastVisitedKey) as? Date) ?? .distantPast
    }()

    private let storeService: CourseStoreService
    private let courseRepo: CourseRepository
    /// 進行中のダウンロードタスク（二重実行防止）
    private var downloadTasks: [String: Task<Void, Never>] = [:]

    // MARK: - 新着判定

    /// 未取得、または更新可能だが未更新のコース
    private func isPendingAcquisition(_ summary: StoreCourseSummary) -> Bool {
        switch downloadStatuses[summary.id] ?? .notDownloaded {
        case .notDownloaded, .updateAvailable:
            return true
        case .downloading, .downloaded:
            return false
        }
    }

    /// 新着 = 最終閲覧日時より後に更新 かつ 未取得または未更新
    func isNew(_ summary: StoreCourseSummary) -> Bool {
        guard let updatedAt = summary.updatedAt else { return false }
        guard updatedAt > lastVisitedStoreAt else { return false }
        return isPendingAcquisition(summary)
    }

    /// 未取得の新着コースが1件以上ある場合 true（+ ボタンバッジ用）
    var hasNewArrivals: Bool {
        storeCourses.contains { isNew($0) }
    }

    /// ストアを閲覧済みとしてマーク（シート閉じ時に呼ぶ）
    func markVisited() {
        let now = Date.now
        lastVisitedStoreAt = now
        UserDefaults.standard.set(now, forKey: Self.lastVisitedKey)
    }

    /// シート表示時にデフォルトフィルターを適用（新着あり→新着、なし→未入手）
    func applyDefaultFilter() {
        selectedDownloadFilter = hasNewArrivals ? .newArrivals : .available
    }

    // MARK: - フィルター

    var filteredCourses: [StoreCourseSummary] {
        var result = storeCourses

        // テキスト検索（入力中は他フィルターより優先）
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
            return result
        }

        // カテゴリフィルター
        if let cat = selectedCategory {
            result = result.filter { $0.parsedCategories.contains(cat) }
        }

        // ダウンロード状態フィルター
        switch selectedDownloadFilter {
        case .all:
            break
        case .newArrivals:
            result = result.filter { isNew($0) }
        case .available:
            result = result.filter { isPendingAcquisition($0) }
        case .installed:
            result = result.filter {
                switch downloadStatuses[$0.id] ?? .notDownloaded {
                case .downloaded, .updateAvailable: return true
                default: return false
                }
            }
        }

        return result
    }

    init(
        storeService: CourseStoreService = AppContainer.shared.courseStoreService,
        courseRepo: CourseRepository = AppContainer.shared.courseRepo
    ) {
        self.storeService = storeService
        self.courseRepo = courseRepo
    }

    // MARK: - インデックス取得

    func loadIndex() async {
        guard !isLoadingIndex else { return }

        // インデックス未取得の場合のみネットワーク通信
        if !isIndexLoaded {
            isLoadingIndex = true
            defer { isLoadingIndex = false }
            do {
                let index = try await storeService.fetchIndex()
                storeCourses = index.courses
                isIndexLoaded = true
            } catch {
                Logger.error("コースストア取得エラー", error: error)
                errorMessage = error.localizedDescription
                showError = true
                return
            }
        }

        // シート表示のたびにローカルDBと照合してステータスを最新化
        // （コース削除後の状態を確実に反映するため）
        do {
            try resolveStatuses(summaries: storeCourses)
        } catch {
            Logger.error("ステータス解決エラー", error: error)
        }

        if hasNewArrivals {
            selectedDownloadFilter = .newArrivals
        }
    }

    // MARK: - ダウンロード

    func download(summary: StoreCourseSummary) {
        // 二重実行防止
        guard downloadTasks[summary.id] == nil else { return }
        let previousStatus = downloadStatuses[summary.id] ?? .notDownloaded
        downloadStatuses[summary.id] = .downloading

        let task = Task {
            do {
                let courseId = CourseJSONParser.uuidFromString(summary.id)
                let existing = try? courseRepo.fetch(id: courseId)
                let isNewCourse = existing == nil
                let course = try await storeService.fetchCourse(
                    jsonPath: summary.jsonPath,
                    existingCourse: existing
                )
                try courseRepo.save(course)
                downloadStatuses[summary.id] = .downloaded
                NotificationCenter.default.post(name: .courseChanged, object: nil)
                // 新規ダウンロードの場合のみハイライト用通知を送信
                if isNewCourse {
                    NotificationCenter.default.post(name: .courseDownloaded, object: course.id)
                }
                Logger.info("コースダウンロード完了: \(summary.title)")
            } catch {
                Logger.error("コースダウンロードエラー: \(summary.title)", error: error)
                downloadStatuses[summary.id] = previousStatus
                errorMessage = error.localizedDescription
                showError = true
            }
            downloadTasks[summary.id] = nil
        }
        downloadTasks[summary.id] = task
    }

    // MARK: - Private

    /// ローカル DB のコースと照合してダウンロード状態を決定する
    private func resolveStatuses(summaries: [StoreCourseSummary]) throws {
        let localCourses = try courseRepo.fetchAll()
        var statuses: [String: CourseDownloadStatus] = [:]

        for summary in summaries {
            let courseId = CourseJSONParser.uuidFromString(summary.id)
            if let local = localCourses.first(where: { $0.id == courseId }) {
                if local.version >= summary.version {
                    statuses[summary.id] = .downloaded
                } else {
                    statuses[summary.id] = .updateAvailable(remoteVersion: summary.version)
                }
            } else {
                statuses[summary.id] = .notDownloaded
            }
        }
        downloadStatuses = statuses
    }
}
