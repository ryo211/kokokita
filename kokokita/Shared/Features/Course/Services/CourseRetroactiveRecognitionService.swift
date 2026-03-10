import Foundation
import CoreLocation
import CoreData

// コースを初めて有効化した時に、過去の証明付き訪問記録を遡って判定するサービス
final class CourseRetroactiveRecognitionService {
    private let courseRepo: CourseRepository
    private let ctx: NSManagedObjectContext

    init(courseRepo: CourseRepository, context: NSManagedObjectContext = CoreDataStack.shared.context) {
        self.courseRepo = courseRepo
        self.ctx = context
    }

    // MARK: - 遡り判定結果

    struct RetroactiveResult {
        let course: Course
        /// チェックインに成功したスポット（チェックイン済みに更新済み）
        let checkedInSpots: [CourseSpot]
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

    // MARK: - Private

    /// 証明付き訪問記録（isManualEntry == false）を全件取得
    private func fetchProofVisits() throws -> [VisitRecord] {
        let req = VisitEntity.fetchRequest()
        req.predicate = NSPredicate(format: "isManualEntry == NO OR isManualEntry == nil")
        req.sortDescriptors = [NSSortDescriptor(key: "timestampUTC", ascending: true)]
        let entities = try ctx.fetch(req)
        return entities.compactMap { e -> VisitRecord? in
            guard let id = e.id, let ts = e.timestampUTC else { return nil }
            return VisitRecord(id: id, timestampUTC: ts, latitude: e.latitude, longitude: e.longitude)
        }
    }

    private struct VisitRecord {
        let id: UUID
        let timestampUTC: Date
        let latitude: Double
        let longitude: Double
    }
}
