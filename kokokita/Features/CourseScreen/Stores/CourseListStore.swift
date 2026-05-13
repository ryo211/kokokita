import Foundation
import Observation

// コース一覧画面の状態管理
@MainActor
@Observable
final class CourseListStore {
    var courses: [Course] = []
    var showError: Bool = false
    var errorMessage: String?
    /// 新規ダウンロードされたコースのID（コース一覧でハイライト表示に使用）
    var newlyAddedCourseIds: Set<UUID> = []

    private let repo: CourseRepository
    /// addObserver の戻り値トークンを保持しないとオブザーバーが即座に解放されるため保存
    private var observers: [NSObjectProtocol] = []

    init(repo: CourseRepository = AppContainer.shared.courseRepo) {
        self.repo = repo

        // チェックイン変更を監視して一覧を再ロード
        let courseObserver = NotificationCenter.default.addObserver(forName: .courseChanged, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.load()
            }
        }

        // 新規ダウンロードを監視してハイライトIDを追加
        let downloadObserver = NotificationCenter.default.addObserver(forName: .courseDownloaded, object: nil, queue: .main) { [weak self] notification in
            guard let self else { return }
            guard let courseId = notification.object as? UUID else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.newlyAddedCourseIds.insert(courseId)
            }
        }

        // 自作コース有効化を監視してNEWバッジIDを追加
        let enabledObserver = NotificationCenter.default.addObserver(forName: .courseEnabled, object: nil, queue: .main) { [weak self] notification in
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

    /// コース一覧を読み込む
    /// - bundled / downloaded コースは常に表示
    /// - isUserCreated == true のコースは isEnabled == true のみ表示
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

    /// コースを削除する
    /// - 自作コース（isUserCreated）: isEnabled = false に設定するだけ（マイリストには残す）
    /// - それ以外（bundled / downloaded）: 物理削除
    func delete(_ courseId: UUID) async {
        do {
            if let course = try repo.fetch(id: courseId), course.isUserCreated {
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
            } else {
                try repo.delete(courseId)
            }
            courses.removeAll { $0.id == courseId }
            NotificationCenter.default.post(name: .courseChanged, object: nil)
        } catch {
            Logger.error("コース削除エラー", error: error)
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
