import Foundation
import Observation

// 新着コースの視認状態
enum NewCourseState: Equatable {
    case unseen          // 追加済みだが未視認
    case seen(Date)      // 視認済み（Date = 初回視認日時）
}

// コース一覧画面の状態管理
@MainActor
@Observable
final class CourseListStore {
    var courses: [Course] = []
    var showError: Bool = false
    var errorMessage: String?
    /// 自動同期中フラグ（ツールバーのインジケーター表示用）
    var isSyncing: Bool = false
    /// 新着コースの視認状態（キーなし = 新着ではない）
    /// 永続化: UserDefaults "newlyAddedCourses" に [UUID文字列: Double] で保存
    /// Double < 0 → unseen、それ以外 → 視認日時（TimeIntervalSinceReferenceDate）
    private(set) var newlyAddedCourses: [UUID: NewCourseState] = [:]

    private let repo: CourseRepository
    private let autoSyncService: CourseAutoSyncService
    private var observers: [NSObjectProtocol] = []

    private static let userDefaultsKey = "newlyAddedCourses"
    private static let newCourseExpirationSeconds: TimeInterval = 86400 // 24時間

    init(
        repo: CourseRepository = AppContainer.shared.courseRepo,
        autoSyncService: CourseAutoSyncService = AppContainer.shared.courseAutoSyncService
    ) {
        self.repo = repo
        self.autoSyncService = autoSyncService
        loadPersistedNewCourses()

        // チェックイン変更を監視して一覧を再ロード
        let courseObserver = NotificationCenter.default.addObserver(
            forName: .courseChanged, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.load()
            }
        }

        // 新規ダウンロードを監視してNEWバッジIDを追加
        let downloadObserver = NotificationCenter.default.addObserver(
            forName: .courseDownloaded, object: nil, queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let courseId = notification.object as? UUID else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.addNewCourse(courseId)
            }
        }

        // 自作コース有効化を監視してNEWバッジIDを追加
        let enabledObserver = NotificationCenter.default.addObserver(
            forName: .courseEnabled, object: nil, queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let courseId = notification.object as? UUID else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.addNewCourse(courseId)
                await self.load()
            }
        }

        observers = [courseObserver, downloadObserver, enabledObserver]
    }

    // MARK: - 新着判定

    func isNew(_ id: UUID) -> Bool {
        guard let state = newlyAddedCourses[id] else { return false }
        switch state {
        case .unseen: return true
        case .seen(let seenAt):
            return Date().timeIntervalSince(seenAt) < Self.newCourseExpirationSeconds
        }
    }

    // MARK: - 新着状態の更新

    private func addNewCourse(_ id: UUID) {
        guard newlyAddedCourses[id] == nil else { return }
        newlyAddedCourses[id] = .unseen
        persistNewCourses()
    }

    /// 新着セクションが画面に表示されたとき、未視認コースに視認日時を記録する
    func markAsSeen(ids: [UUID]) {
        let now = Date()
        var changed = false
        for id in ids {
            if case .unseen = newlyAddedCourses[id] {
                newlyAddedCourses[id] = .seen(now)
                changed = true
            }
        }
        if changed { persistNewCourses() }
    }

    /// 詳細画面を開いたコースを新着リストから除去する
    func markAsOpened(_ id: UUID) {
        guard newlyAddedCourses[id] != nil else { return }
        newlyAddedCourses.removeValue(forKey: id)
        persistNewCourses()
    }

    // MARK: - 永続化

    private func loadPersistedNewCourses() {
        guard let dict = UserDefaults.standard.dictionary(forKey: Self.userDefaultsKey) as? [String: Double] else { return }
        var result: [UUID: NewCourseState] = [:]
        let now = Date()
        for (key, value) in dict {
            guard let id = UUID(uuidString: key) else { continue }
            if value < 0 {
                result[id] = .unseen
            } else {
                let seenAt = Date(timeIntervalSinceReferenceDate: value)
                // 24時間以上経過しているものはロード時に除外
                if now.timeIntervalSince(seenAt) < Self.newCourseExpirationSeconds {
                    result[id] = .seen(seenAt)
                }
            }
        }
        newlyAddedCourses = result
    }

    private func persistNewCourses() {
        var dict: [String: Double] = [:]
        for (id, state) in newlyAddedCourses {
            switch state {
            case .unseen:
                dict[id.uuidString] = -1.0
            case .seen(let date):
                dict[id.uuidString] = date.timeIntervalSinceReferenceDate
            }
        }
        UserDefaults.standard.set(dict, forKey: Self.userDefaultsKey)
    }

    // MARK: - ロード

    /// コース一覧を読み込む
    /// - isHidden=true のコースは除外
    /// - isUserCreated=true のコースは isEnabled=true のもののみ表示
    func load() async {
        do {
            let all = try repo.fetchAll()
            courses = all.filter { course in
                !course.isUserCreated || course.isEnabled
            }
        } catch {
            Logger.error("コース一覧読み込みエラー", error: error)
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    /// 自動同期してからコース一覧を読み込む（画面初期表示時に呼ぶ）
    func syncAndLoad() async {
        isSyncing = true
        await autoSyncService.sync()
        isSyncing = false
        await load()
    }

    // MARK: - 非表示・削除

}

// 遡り判定結果（sheet 表示用の Identifiable ラッパー）
struct RetroactiveResultItem: Identifiable, Equatable {
    let id = UUID()
    let course: Course
    let checkedInSpots: [CourseSpot]
}
