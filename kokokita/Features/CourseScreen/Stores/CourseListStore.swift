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

    /// コースの有効/無効を切り替える
    func toggleEnabled(_ course: Course) {
        let wasEverEnabled = course.everEnabled
        let newEnabled = !course.isEnabled

        do {
            try repo.setEnabled(course.id, enabled: newEnabled)
            // UI 即時更新
            if let idx = courses.firstIndex(where: { $0.id == course.id }) {
                courses[idx] = Course(
                    id: course.id,
                    courseType: course.courseType,
                    title: course.title,
                    summary: course.summary,
                    source: course.source,
                    isUserCreated: course.isUserCreated,
                    version: course.version,
                    recognitionRadiusMeters: course.recognitionRadiusMeters,
                    isEnabled: newEnabled,
                    everEnabled: newEnabled ? true : course.everEnabled,
                    detailUrl: course.detailUrl,
                    coverImageUrl: course.coverImageUrl,
                    createdAt: course.createdAt,
                    updatedAt: Date(),
                    spots: course.spots
                )
            }

            // 初めて有効化した場合のみ遡り判定を実行
            if newEnabled && !wasEverEnabled {
                Task {
                    await runRetroactiveRecognition(courseId: course.id)
                }
            }
        } catch {
            Logger.error("コース有効化エラー", error: error)
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    /// 遡り判定を実行
    private func runRetroactiveRecognition(courseId: UUID) async {
        guard let svc = retroactiveService else { return }
        do {
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
