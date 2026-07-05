import Foundation

// アプリ起動時にサーバーからコース一覧を自動同期するサービス
// - 新規コース: 自動ダウンロードして保存
// - バージョン更新コース: 自動更新（チェックイン状態は保持）
// - index.jsonから消えたコース: 削除（自作コースは除く）
// - isHidden=true のコース: 自動同期でも復活させない
final class CourseAutoSyncService {
    private let storeService: CourseStoreService
    private let courseRepo: CourseRepository

    init(
        storeService: CourseStoreService = AppContainer.shared.courseStoreService,
        courseRepo: CourseRepository = AppContainer.shared.courseRepo
    ) {
        self.storeService = storeService
        self.courseRepo = courseRepo
    }

    // MARK: - 同期実行

    func sync() async {
        do {
            let index = try await storeService.fetchIndex()
            let localCourses = try courseRepo.fetchAll()

            // ローカルのダウンロード済みコースを ID でマッピング
            let localDownloaded: [UUID: Course] = localCourses
                .filter { $0.source == .downloaded }
                .reduce(into: [:]) { dict, c in dict[c.id] = c }

            var hasNewCourse = false

            for summary in index.courses {
                let courseId = CourseJSONParser.uuidFromString(summary.id)
                let existing = localDownloaded[courseId]

                // ユーザーが非表示にしたコースはスキップ（自動同期で復活させない）
                if let existing, existing.isHidden {
                    continue
                }

                // 新規 or バージョンアップがある場合のみダウンロード
                let needsDownload = existing == nil || existing!.version < summary.version
                guard needsDownload else { continue }

                do {
                    let isNew = existing == nil
                    let course = try await storeService.fetchCourse(
                        jsonPath: summary.jsonPath,
                        existingCourse: existing
                    )
                    try courseRepo.save(course)

                    if isNew {
                        hasNewCourse = true
                        NotificationCenter.default.post(name: .courseDownloaded, object: course.id)
                        Logger.info("コース自動追加: \(summary.title)")
                    } else {
                        Logger.info("コース自動更新: \(summary.title) (v\(existing!.version) → v\(summary.version))")
                    }
                } catch {
                    Logger.error("コース同期エラー: \(summary.title)", error: error)
                }
            }

            // index.json から消えたダウンロードコースを削除
            // 自作コース（source == .user）は除外する
            let importedIds = Set(index.courses.map { CourseJSONParser.uuidFromString($0.id) })
            let toDelete = localCourses.filter {
                $0.source == .downloaded && !importedIds.contains($0.id)
            }
            for course in toDelete {
                try courseRepo.delete(course.id)
                Logger.info("コース自動削除（index から除外）: \(course.title)")
            }

            if hasNewCourse || !toDelete.isEmpty {
                NotificationCenter.default.post(name: .courseChanged, object: nil)
            }

            Logger.info("コース自動同期完了")
        } catch {
            Logger.error("コース自動同期エラー", error: error)
        }
    }
}
