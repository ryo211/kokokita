import Foundation

// アプリ起動時にサーバーからコース一覧を自動同期するサービス
// - 新規コース: 自動ダウンロードして保存
// - バージョン更新コース: 自動更新（チェックイン状態は保持）
// - index.jsonから消えたコース: 削除（自作コースは除く）
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

    /// - Parameter onProgress: ダウンロード件数ベースの進捗（0.0〜1.0）を通知するコールバック（省略可）
    ///   ウェルカム画面のプログレスバー表示用。既存呼び出し元は省略可能で挙動は変わらない
    /// - Returns: index.jsonの取得に成功したか（ネットワーク到達性の指標。個別コースのダウンロード
    ///   失敗はコースごとにログするだけで全体の成否には影響させない）
    @discardableResult
    func sync(onProgress: (@MainActor (Double) -> Void)? = nil) async -> Bool {
        do {
            let index = try await storeService.fetchIndex()
            let localCourses = try courseRepo.fetchAll()

            // ローカルのダウンロード済みコースを ID でマッピング
            let localDownloaded: [UUID: Course] = localCourses
                .filter { $0.source == .downloaded }
                .reduce(into: [:]) { dict, c in dict[c.id] = c }

            var hasNewCourse = false

            // 新規 or バージョンアップが必要なコースのみを対象に進捗を計算
            let targets = index.courses.filter { summary in
                let courseId = CourseJSONParser.uuidFromString(summary.id)
                let existing = localDownloaded[courseId]
                return existing == nil || existing!.version < summary.version
            }
            let total = max(targets.count, 1)
            var completed = 0

            if targets.isEmpty {
                await onProgress?(1.0)
            }

            for summary in targets {
                let courseId = CourseJSONParser.uuidFromString(summary.id)
                let existing = localDownloaded[courseId]

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

                completed += 1
                await onProgress?(Double(completed) / Double(total))
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
            return true
        } catch {
            Logger.error("コース自動同期エラー", error: error)
            await onProgress?(1.0)  // 失敗時もプログレスバー・ボタンをブロックしたままにしない
            return false
        }
    }
}
