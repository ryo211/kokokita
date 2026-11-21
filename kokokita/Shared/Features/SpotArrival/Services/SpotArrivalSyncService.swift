import Foundation
import CoreLocation

/// 到達記録の送信を統括するサービス。
/// - 記録確定時: キューに積んで即時送信を試みる（記録確定自体はブロックしない）
/// - アプリ起動時・フォアグラウンド復帰時: 未送信分をまとめて再送する
/// - 初回同意時: 機能実装前も含め、過去の達成済みスポットを全件キューに積む
/// doc/server-feature-design.md フェーズ1「送信のタイミング」「同意とオプトアウト」参照
struct SpotArrivalSyncService {
    private let outboxRepo: SpotArrivalOutboxRepository
    private let courseRepo: CourseRepository
    private let visitRepo: CoreDataVisitRepository
    private let apiClient: SpotArrivalAPIClient

    init(
        outboxRepo: SpotArrivalOutboxRepository = AppContainer.shared.spotArrivalOutboxRepo,
        courseRepo: CourseRepository = AppContainer.shared.courseRepo,
        visitRepo: CoreDataVisitRepository = AppContainer.shared.repo,
        apiClient: SpotArrivalAPIClient = SpotArrivalAPIClient()
    ) {
        self.outboxRepo = outboxRepo
        self.courseRepo = courseRepo
        self.visitRepo = visitRepo
        self.apiClient = apiClient
    }

    /// コース認識でチェックインが確定した直後に呼ぶ。キューへの登録は同期・即時に行い、
    /// サーバーへの送信自体は非同期・ベストエフォートで行う（記録確定のクリティカルパスをブロックしない）
    func enqueueAndSendImmediately(
        courseId: UUID,
        spotId: UUID,
        visitId: UUID,
        distanceMeters: Double,
        achievedAt: Date
    ) {
        enqueue(courseId: courseId, spotId: spotId, visitId: visitId, distanceMeters: distanceMeters, arrivedAt: achievedAt)

        Task.detached(priority: .utility) { [self] in
            await flushPending()
        }
    }

    /// 未送信の到達記録をまとめて送信する。アプリ起動時・フォアグラウンド復帰時に呼ぶ想定
    func flushPending() async {
        // 同意画面実装前は常にfalseなので、ここで確実に送信をブロックする
        guard MetaCollectionSettings.shared.isConsented else { return }
        guard let pending = try? outboxRepo.fetchPending(), !pending.isEmpty else { return }

        for arrival in pending {
            // course.rawId が未バックフィルの間は送信できないため、次回の呼び出しに持ち越す
            guard let resolved = resolve(arrival) else {
                Logger.info("到達記録の送信を保留（course.rawId未解決）: courseId=\(arrival.courseId) spotId=\(arrival.spotId)")
                continue
            }

            switch await apiClient.send(resolved) {
            case .success(let result):
                try? outboxRepo.markSent(arrival.id, rank: result.rank)
                // 達成シート表示中であればリアルタイムに順位を反映するための通知
                // （画面が無い場合はただ誰にも受信されないだけで無害）
                if let rank = result.rank {
                    NotificationCenter.default.post(
                        name: .spotArrivalRankDetermined,
                        object: SpotArrivalRankPayload(visitId: arrival.visitId, spotId: arrival.spotId, rank: rank)
                    )
                }
            case .failure(let error):
                // サーバー未設定・ネットワーク不通等。キューに残したまま次回再試行する
                Logger.error("到達記録の送信に失敗（キューには残します）: course=\(resolved.courseRawId) spot=\(resolved.spotStringId)", error: error)
            }
        }
    }

    /// 同意直後、およびアプリ起動時に呼ぶ。機能実装前も含め、達成済みの全スポットをキューに積む。
    /// 冪等（(visitId, spotId)から導出したidで重複排除）なので、何度呼んでも安全。
    /// 起動時にも毎回呼ぶことで、rawId未解決等の理由で前回取りこぼした分も次回必ず再キューイングされる
    func enqueueAllHistoricalArrivals() {
        guard MetaCollectionSettings.shared.isConsented else { return }
        guard let courses = try? courseRepo.fetchAll() else {
            Logger.error("enqueueAllHistoricalArrivals: courseRepo.fetchAll()に失敗")
            return
        }

        for course in courses {
            for spot in course.spots where spot.isCheckedIn {
                for visitId in spot.visitIds {
                    let distance = distanceMeters(visitId: visitId, spot: spot)
                    let arrivedAt = (try? visitRepo.get(by: visitId))?.visit.timestampUTC ?? spot.firstCheckedInAt ?? Date()
                    enqueue(
                        courseId: course.id,
                        spotId: spot.id,
                        visitId: visitId,
                        distanceMeters: distance,
                        arrivedAt: arrivedAt
                    )
                }
            }
        }

        Task.detached(priority: .utility) { [self] in
            await flushPending()
        }
    }

    // MARK: - Private

    private func enqueue(courseId: UUID, spotId: UUID, visitId: UUID, distanceMeters: Double, arrivedAt: Date) {
        let arrival = SpotArrival(
            id: SpotArrival.makeId(visitId: visitId, spotId: spotId),
            visitId: visitId,
            courseId: courseId,
            spotId: spotId,
            distanceMeters: distanceMeters,
            arrivedAt: arrivedAt,
            appVersion: Self.currentAppVersion,
            isSent: false,
            rank: nil
        )
        do {
            try outboxRepo.enqueue(arrival)
        } catch {
            Logger.error("到達記録のキュー登録に失敗", error: error)
        }
    }

    private func distanceMeters(visitId: UUID, spot: CourseSpot) -> Double {
        guard let visit = try? visitRepo.get(by: visitId) else { return 0 }
        let visitLocation = CLLocation(latitude: visit.visit.latitude, longitude: visit.visit.longitude)
        let spotLocation = CLLocation(latitude: spot.latitude, longitude: spot.longitude)
        return visitLocation.distance(from: spotLocation)
    }

    private func resolve(_ arrival: SpotArrival) -> ResolvedSpotArrival? {
        guard let course = try? courseRepo.fetch(id: arrival.courseId), let rawId = course.rawId else { return nil }
        guard let spot = course.spots.first(where: { $0.id == arrival.spotId }) else { return nil }
        return ResolvedSpotArrival(
            id: arrival.id,
            visitId: arrival.visitId,
            courseRawId: rawId,
            spotStringId: spot.spotId,
            distanceMeters: arrival.distanceMeters,
            arrivedAt: arrival.arrivedAt,
            appVersion: arrival.appVersion
        )
    }

    private static var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }
}
