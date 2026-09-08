import Foundation
import CoreLocation
import CoreData

// コースを初めて有効化した時に、過去の証明付き訪問記録を遡って判定するサービス
final class CourseRetroactiveRecognitionService {
    private let courseRepo: CourseRepository
    private let visitRepo: CoreDataVisitRepository
    private let ctx: NSManagedObjectContext

    init(
        courseRepo: CourseRepository,
        visitRepo: CoreDataVisitRepository,
        context: NSManagedObjectContext = CoreDataStack.shared.context
    ) {
        self.courseRepo = courseRepo
        self.visitRepo = visitRepo
        self.ctx = context
    }

    // MARK: - 遡り判定結果

    struct RetroactiveResult {
        let course: Course
        /// チェックインに成功したスポット（チェックイン済みに更新済み）
        let checkedInSpots: [CourseSpot]
    }

    // MARK: - 手動確認用の候補

    struct RetroactiveCandidate: Identifiable {
        var id: UUID { spot.id }
        let course: Course
        let spot: CourseSpot
        /// 認識半径内にある証明付き訪問記録（複数の場合あり、新しい順）
        let matchedVisits: [VisitAggregate]
    }

    // MARK: - 遡り判定

    /// コースを初めて有効化した時に呼び出す
    /// - everEnabled: false → true になったコースのみ対象
    /// - 過去の証明付き訪問記録（isManualEntry == false）を全件チェック
    /// - ヒットしたスポットの firstCheckedInAt を過去の訪問日時に設定
    func recognize(for courseId: UUID) throws -> RetroactiveResult? {
        guard var course = try courseRepo.fetch(id: courseId) else { return nil }

        // 証明付き訪問記録（isManualEntry == false）を全件取得
        let proofVisits = try fetchProofVisits()
        guard !proofVisits.isEmpty else { return nil }

        // 未チェックインスポットのみ判定対象
        let uncheckedSpots = course.spots.filter { !$0.isCheckedIn }
        guard !uncheckedSpots.isEmpty else { return nil }

        let defaultRadius = course.recognitionRadiusMeters
        var checkedInSpots: [CourseSpot] = []

        for spot in uncheckedSpots {
            let spotLocation = CLLocation(latitude: spot.latitude, longitude: spot.longitude)
            let spotRadius = spot.recognitionRadiusMeters ?? defaultRadius

            // この spot に最も近い（かつ認識半径内の）証明付き訪問を探す
            let candidates = proofVisits.filter { visit in
                let visitLocation = CLLocation(latitude: visit.latitude, longitude: visit.longitude)
                let dist = visitLocation.distance(from: spotLocation)
                return dist <= spotRadius
            }

            if let earliest = candidates.min(by: { $0.timestampUTC < $1.timestampUTC }) {
                // 全候補の訪問記録を紐づける（firstCheckedInAt は最古の訪問日時で固定）
                for candidate in candidates {
                    try courseRepo.checkIn(spotId: spot.id, visitId: candidate.id)
                }
                checkedInSpots.append(spot)
                Logger.info("遡りチェックイン: \(spot.name) - \(earliest.timestampUTC)（紐づけ訪問数: \(candidates.count)）")
            }
        }

        guard !checkedInSpots.isEmpty else { return nil }

        // 最新のコース情報を再取得（visits リレーション更新後）
        course = try courseRepo.fetch(id: courseId) ?? course

        // checkedInSpots を再フェッチ済みコースのスポットで上書き
        // （visits が実際にリンクされたスポットのみが isCheckedIn == true になる）
        let checkedInIds = Set(checkedInSpots.map { $0.id })
        let updatedCheckedInSpots = course.spots.filter { checkedInIds.contains($0.id) && $0.isCheckedIn }

        guard !updatedCheckedInSpots.isEmpty else { return nil }

        return RetroactiveResult(course: course, checkedInSpots: updatedCheckedInSpots)
    }

    // MARK: - 手動確認用の候補検出

    /// 全コース横断で、未達成スポットと条件を満たす訪問記録の組み合わせを検出する（checkIn は行わない）
    func findCandidates() throws -> [RetroactiveCandidate] {
        let proofVisits = try fetchProofVisits()
        guard !proofVisits.isEmpty else { return [] }

        let courses = try courseRepo.fetchAll()
        var results: [RetroactiveCandidate] = []

        for course in courses {
            let defaultRadius = course.recognitionRadiusMeters
            for spot in course.spots where !spot.isCheckedIn {
                let spotLocation = CLLocation(latitude: spot.latitude, longitude: spot.longitude)
                let spotRadius = spot.recognitionRadiusMeters ?? defaultRadius

                let matchedRecords = proofVisits.filter { visit in
                    let visitLocation = CLLocation(latitude: visit.latitude, longitude: visit.longitude)
                    return visitLocation.distance(from: spotLocation) <= spotRadius
                }.sorted { $0.timestampUTC > $1.timestampUTC }

                guard !matchedRecords.isEmpty else { continue }

                let matchedVisits = matchedRecords.compactMap { try? visitRepo.get(by: $0.id) }
                guard !matchedVisits.isEmpty else { continue }

                results.append(RetroactiveCandidate(course: course, spot: spot, matchedVisits: matchedVisits))
            }
        }

        return results
    }

    // MARK: - Private

    /// 証明付き訪問記録（isManualEntry == false）を全件取得
    // メインスレッド外から呼ばれる可能性に備え、performAndWait でコンテキスト自身のキュー上での実行を保証する
    private func fetchProofVisits() throws -> [VisitRecord] {
        try ctx.performAndWait {
            let req = VisitEntity.fetchRequest()
            req.predicate = NSPredicate(format: "isManualEntry == NO OR isManualEntry == nil")
            req.sortDescriptors = [NSSortDescriptor(key: "timestampUTC", ascending: true)]
            let entities = try ctx.fetch(req)
            return entities.compactMap { e -> VisitRecord? in
                guard let id = e.id, let ts = e.timestampUTC else { return nil }
                return VisitRecord(id: id, timestampUTC: ts, latitude: e.latitude, longitude: e.longitude)
            }
        }
    }

    private struct VisitRecord {
        let id: UUID
        let timestampUTC: Date
        let latitude: Double
        let longitude: Double
    }
}
