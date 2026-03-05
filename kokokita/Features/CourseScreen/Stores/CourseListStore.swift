import Foundation
import Observation

// コース一覧画面の状態管理
@MainActor
@Observable
final class CourseListStore {
    var courses: [Course] = []
    var showError: Bool = false
    var errorMessage: String?
    /// 遡り判定結果（シートで表示）
    var retroactiveResult: RetroactiveResultItem?

    private let repo: CourseRepository
    private let retroactiveService: CourseRetroactiveRecognitionService?

    init(
        repo: CourseRepository = AppContainer.shared.courseRepo,
        retroactiveService: CourseRetroactiveRecognitionService? = AppContainer.shared.retroactiveService
    ) {
        self.repo = repo
        self.retroactiveService = retroactiveService

        // チェックイン変更を監視して一覧を再ロード
        NotificationCenter.default.addObserver(forName: .courseChanged, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.load()
            }
        }
    }

    /// コース一覧を読み込む（遡り判定未実施コースを自動実行）
    func load() async {
        do {
            courses = try repo.fetchAll()
            // everEnabled == false のコースは初回インポート扱い → 遡り判定を自動実行
            for course in courses where !course.everEnabled {
                Task {
                    await runRetroactiveRecognition(courseId: course.id)
                }
            }
        } catch {
            Logger.error("コース一覧読み込みエラー", error: error)
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    /// 遡り判定を実行
    private func runRetroactiveRecognition(courseId: UUID) async {
        do {
            // 二重実行防止のため先にフラグをセット
            try repo.setEverEnabled(courseId)

            guard let svc = retroactiveService else { return }

            let result = try await Task.detached(priority: .background) {
                try svc.recognize(for: courseId)
            }.value

            guard let r = result, !r.checkedInSpots.isEmpty else { return }

            // UI 更新
            await load()
            retroactiveResult = RetroactiveResultItem(
                course: r.course,
                checkedInSpots: r.checkedInSpots
            )
        } catch {
            Logger.error("遡り判定エラー", error: error)
        }
    }
}

// 遡り判定結果（sheet 表示用の Identifiable ラッパー）
struct RetroactiveResultItem: Identifiable {
    let id = UUID()
    let course: Course
    let checkedInSpots: [CourseSpot]
}
