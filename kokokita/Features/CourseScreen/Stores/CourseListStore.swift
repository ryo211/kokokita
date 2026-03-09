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

    init(repo: CourseRepository = AppContainer.shared.courseRepo) {
        self.repo = repo

        // チェックイン変更を監視して一覧を再ロード
        NotificationCenter.default.addObserver(forName: .courseChanged, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.load()
            }
        }

        // 新規ダウンロードを監視してハイライトIDを追加
        NotificationCenter.default.addObserver(forName: .courseDownloaded, object: nil, queue: .main) { [weak self] notification in
            guard let self else { return }
            guard let courseId = notification.object as? UUID else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.newlyAddedCourseIds.insert(courseId)
            }
        }
    }

    /// コース一覧を読み込む
    func load() async {
        do {
            courses = try repo.fetchAll()
        } catch {
            Logger.error("コース一覧読み込みエラー", error: error)
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    /// コースを削除する
    func delete(_ courseId: UUID) async {
        do {
            try repo.delete(courseId)
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
