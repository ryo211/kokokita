import Foundation
import Observation

// コース一覧画面の状態管理
@MainActor
@Observable
final class CourseListStore {
    var courses: [Course] = []
    var showError: Bool = false
    var errorMessage: String?
    /// 自動同期中フラグ（ツールバーのインジケーター表示用）
    var isSyncing: Bool = false
    /// 新規追加されたコースのID（コース一覧でNEWバッジ表示に使用）
    var newlyAddedCourseIds: Set<UUID> = []

    private let repo: CourseRepository
    private let autoSyncService: CourseAutoSyncService
    private var observers: [NSObjectProtocol] = []

    init(
        repo: CourseRepository = AppContainer.shared.courseRepo,
        autoSyncService: CourseAutoSyncService = AppContainer.shared.courseAutoSyncService
    ) {
        self.repo = repo
        self.autoSyncService = autoSyncService

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
                self.newlyAddedCourseIds.insert(courseId)
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
                self.newlyAddedCourseIds.insert(courseId)
                await self.load()
            }
        }

        observers = [courseObserver, downloadObserver, enabledObserver]
    }

    // MARK: - ロード

    /// コース一覧を読み込む
    /// - isHidden=true のコースは除外
    /// - isUserCreated=true のコースは isEnabled=true のもののみ表示
    func load() async {
        do {
            let all = try repo.fetchAll()
            courses = all.filter { course in
                guard !course.isHidden else { return false }
                return !course.isUserCreated || course.isEnabled
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

    /// コースをコース一覧から取り除く
    /// - isUserCreated: isEnabled=false に設定（マイリストには残す）
    /// - downloaded: isHidden=true に設定（自動同期でも復活しない）
    /// - bundled: 何もしない（UIレベルで非表示ボタンを出さない）
    func hide(_ courseId: UUID) async {
        do {
            guard let course = try repo.fetch(id: courseId) else { return }

            if course.isUserCreated {
                // 自作コースはコース一覧から非表示にするだけで実体は残す
                let disabled = Course(
                    id: course.id,
                    courseType: course.courseType,
                    title: course.title,
                    summary: course.summary,
                    source: course.source,
                    isUserCreated: course.isUserCreated,
                    version: course.version,
                    recognitionRadiusMeters: course.recognitionRadiusMeters,
                    everEnabled: course.everEnabled,
                    isEnabled: false,
                    isHidden: false,
                    allowRetroactive: course.allowRetroactive,
                    detailUrl: course.detailUrl,
                    coverImageUrl: course.coverImageUrl,
                    imageCredit: course.imageCredit,
                    localCoverImagePath: course.localCoverImagePath,
                    createdAt: course.createdAt,
                    updatedAt: Date(),
                    categories: course.categories,
                    sections: course.sections
                )
                try repo.save(disabled)
            } else if course.source == .downloaded {
                // ダウンロードコースは非表示フラグを立てる（自動同期でも復活しない）
                try repo.hide(courseId)
            }
            // bundled コースは操作しない

            courses.removeAll { $0.id == courseId }
            NotificationCenter.default.post(name: .courseChanged, object: nil)
        } catch {
            Logger.error("コース非表示エラー", error: error)
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// 遡り判定結果（sheet 表示用の Identifiable ラッパー）
struct RetroactiveResultItem: Identifiable, Equatable {
    let id = UUID()
    let course: Course
    let checkedInSpots: [CourseSpot]
}
