import Foundation
import Observation

// コースストアシートの状態管理
@MainActor
@Observable
final class CourseStoreSheetStore {
    var storeCourses: [StoreCourseSummary] = []
    var downloadStatuses: [String: CourseDownloadStatus] = [:]
    var selectedCategory: CourseCategory? = nil
    var isLoadingIndex: Bool = false
    var showError: Bool = false
    var errorMessage: String?

    private let storeService: CourseStoreService
    private let courseRepo: CourseRepository
    /// 進行中のダウンロードタスク（二重実行防止）
    private var downloadTasks: [String: Task<Void, Never>] = [:]

    var filteredCourses: [StoreCourseSummary] {
        guard let cat = selectedCategory else { return storeCourses }
        return storeCourses.filter { $0.parsedCategories.contains(cat) }
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
        isLoadingIndex = true
        defer { isLoadingIndex = false }

        do {
            let index = try await storeService.fetchIndex()
            storeCourses = index.courses
            try resolveStatuses(summaries: index.courses)
        } catch {
            Logger.error("コースストア取得エラー", error: error)
            errorMessage = error.localizedDescription
            showError = true
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
                let isNew = existing == nil
                let course = try await storeService.fetchCourse(
                    jsonPath: summary.jsonPath,
                    existingCourse: existing
                )
                try courseRepo.save(course)
                downloadStatuses[summary.id] = .downloaded
                NotificationCenter.default.post(name: .courseChanged, object: nil)
                // 新規ダウンロードの場合のみハイライト用通知を送信
                if isNew {
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
