import Foundation

/// コースへの「関心度」イベント（閲覧・お気に入り追加等）の記録・送信を統括するサービス。
/// SpotArrivalSyncServiceと同じ設計（ローカルに貯めてから、アプリ起動時・フォアグラウンド復帰時にまとめて送る）
/// doc/server-feature-design.md フェーズ1「収集するデータ」「送信のタイミング」参照
struct CourseEventSyncService {
    private let outboxRepo: CourseEventOutboxRepository
    private let courseRepo: CourseRepository
    private let apiClient: SpotArrivalAPIClient

    init(
        outboxRepo: CourseEventOutboxRepository = AppContainer.shared.courseEventOutboxRepo,
        courseRepo: CourseRepository = AppContainer.shared.courseRepo,
        apiClient: SpotArrivalAPIClient = SpotArrivalAPIClient()
    ) {
        self.outboxRepo = outboxRepo
        self.courseRepo = courseRepo
        self.apiClient = apiClient
    }

    /// コース詳細画面を開いた時に呼ぶ。1日1回まで（ローカルで冪等化済みなので何度呼んでも安全）
    func recordView(courseId: UUID) {
        recordEvent(courseId: courseId, spotId: nil, type: .view)
    }

    /// コースをお気に入りに追加した時に呼ぶ（削除時は呼ばない。「関心度」の一方向シグナルとして扱う）
    func recordFavoriteAdd(courseId: UUID) {
        recordEvent(courseId: courseId, spotId: nil, type: .favoriteAdd)
    }

    /// スポットをお気に入りに追加した時に呼ぶ（削除時は呼ばない。「関心度」の一方向シグナルとして扱う）
    func recordSpotFavoriteAdd(courseId: UUID, spotId: UUID) {
        recordEvent(courseId: courseId, spotId: spotId, type: .spotFavoriteAdd)
    }

    /// 未送信のイベントをまとめて送信する。アプリ起動時・フォアグラウンド復帰時に呼ぶ想定
    func flushPending() async {
        guard MetaCollectionSettings.shared.isConsented else { return }
        guard let pending = try? outboxRepo.fetchPending(), !pending.isEmpty else { return }

        for event in pending {
            // course.rawId が未バックフィルの間は送信できないため、次回の呼び出しに持ち越す
            guard let course = try? courseRepo.fetch(id: event.courseId), let rawId = course.rawId else {
                continue
            }
            // スポット単位のイベントは、そのスポットの文字列spotIdも解決する。
            // スポットが見つからない（コース更新で削除された等）場合は送信を見送る
            var spotStringId: String?
            if let spotId = event.spotId {
                guard let spot = course.spots.first(where: { $0.id == spotId }) else { continue }
                spotStringId = spot.spotId
            }

            switch await apiClient.sendCourseEvent(id: event.id, courseRawId: rawId, spotStringId: spotStringId, version: course.version, type: event.type) {
            case .success:
                try? outboxRepo.markSent(event.id)
            case .failure(let error):
                Logger.error("コースイベントの送信に失敗（キューには残します）: course=\(rawId) type=\(event.type.rawValue)", error: error)
            }
        }
    }

    // MARK: - Private

    private func recordEvent(courseId: UUID, spotId: UUID?, type: CourseEventType) {
        guard MetaCollectionSettings.shared.isConsented else { return }
        do {
            try outboxRepo.recordEventIfNeeded(courseId: courseId, spotId: spotId, type: type)
        } catch {
            Logger.error("コースイベントの記録に失敗", error: error)
        }
    }
}
