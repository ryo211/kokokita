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
        /// 達成日時
        let achievedAt: Date
    }

    // MARK: - 判定

    /// 指定座標に対して有効コース全件を判定し、ヒットしたコース×スポットを返す
    /// - 条件A: isManualEntry == false（後付け記録は対象外）
    /// - チェックイン済みスポットも再認識対象（再訪問を正しく記録するため）
    /// - 同一コース内複数該当 → 該当スポットをすべて採用
    /// - 複数コース該当 → 全件返す
    func recognize(latitude: Double, longitude: Double, isManualEntry: Bool) throws -> [RecognitionResult] {
        guard !isManualEntry else { return [] }

        let courses = try repo.fetchAll()
        let location = CLLocation(latitude: latitude, longitude: longitude)
        var results: [RecognitionResult] = []
        let now = Date()

        for course in courses {
            // isEnabled == false のコースは判定対象外
            guard course.isEnabled else { continue }
            // 全スポット対象（チェックイン済みでも再認識する）
            guard !course.spots.isEmpty else { continue }

            // 認識半径に応じた BBox プレフィルタ
            let maxRadius = course.spots
                .map { $0.recognitionRadiusMeters ?? course.recognitionRadiusMeters }
                .max() ?? course.recognitionRadiusMeters
            let latDelta = latitudeDelta(forMeters: maxRadius)
            let lonDelta = longitudeDelta(forMeters: maxRadius, at: latitude)
            let filtered = course.spots.filter { spot in
                abs(spot.latitude - latitude) <= latDelta &&
                abs(spot.longitude - longitude) <= lonDelta
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

            for (spot, dist) in candidates.sorted(by: { $0.1 < $1.1 }) {
                results.append(RecognitionResult(
                    course: course,
                    spot: spot,
                    distanceMeters: dist,
                    achievedAt: now
                ))
            }
        }

        return results
    }

    private func latitudeDelta(forMeters meters: Double) -> CLLocationDegrees {
        meters / 111_000.0
    }

    private func longitudeDelta(forMeters meters: Double, at latitude: Double) -> CLLocationDegrees {
        let cosLat = max(cos(latitude * .pi / 180.0), 0.01)
        return meters / (111_000.0 * cosLat)
    }
}
