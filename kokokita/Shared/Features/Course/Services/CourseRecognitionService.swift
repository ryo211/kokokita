import Foundation
import CoreLocation

// 訪問記録の位置情報がコーススポットに合致するか判定するサービス
final class CourseRecognitionService {
    private let repo: CourseRepository

    init(repo: CourseRepository) {
        self.repo = repo
    }

    // MARK: - 判定結果

    struct RecognitionResult {
        let course: Course
        let spot: CourseSpot
        /// 判定時の距離（メートル）
        let distanceMeters: Double
    }

    // MARK: - 判定

    /// 指定座標に対して有効コース全件を判定し、ヒットしたコース×スポットを返す
    /// - 条件A: isManualEntry == false（後付け記録は対象外）
    /// - 条件B: spot.isCheckedIn == false
    /// - 同一コース内複数該当 → 最短距離のみ採用
    /// - 複数コース該当 → 全件返す
    func recognize(latitude: Double, longitude: Double, isManualEntry: Bool) throws -> [RecognitionResult] {
        guard !isManualEntry else { return [] }

        let courses = try repo.fetchEnabled()
        let location = CLLocation(latitude: latitude, longitude: longitude)
        var results: [RecognitionResult] = []

        for course in courses {
            // 未チェックインスポットのみ対象
            let uncheckedSpots = course.spots.filter { !$0.isCheckedIn }
            guard !uncheckedSpots.isEmpty else { continue }

            // BBox プレフィルタ（±0.003度 ≒ 約330m）
            let filtered = uncheckedSpots.filter { spot in
                abs(spot.latitude - latitude) <= 0.003 &&
                abs(spot.longitude - longitude) <= 0.003
            }
            guard !filtered.isEmpty else { continue }

            // 精密距離計算して認識半径以内のスポットを抽出
            let radius = course.recognitionRadiusMeters
            let candidates = filtered.compactMap { spot -> (CourseSpot, Double)? in
                let spotLocation = CLLocation(latitude: spot.latitude, longitude: spot.longitude)
                let dist = location.distance(from: spotLocation)
                let spotRadius = spot.recognitionRadiusMeters ?? radius
                return dist <= spotRadius ? (spot, dist) : nil
            }
            guard !candidates.isEmpty else { continue }

            // 同一コース内で最短距離のスポットのみ採用
            if let (bestSpot, bestDist) = candidates.min(by: { $0.1 < $1.1 }) {
                results.append(RecognitionResult(
                    course: course,
                    spot: bestSpot,
                    distanceMeters: bestDist
                ))
            }
        }

        return results
    }
}
