import Foundation

/// スポット到達記録（サーバー送信待ちキューに保持するローカルモデル）。
///
/// 1件のVisit（GPS記録）が複数のコーススポットに同時該当することがある
/// （例: 認識半径が重なる2つのスポット、複数コースにまたがる該当）ため、
/// idはvisitIdそのものではなく (visitId, spotId) から決定論的に導出する。
/// 同じ組み合わせへの再送は同じidになるため、サーバー側の重複挿入も防げる
struct SpotArrival: Identifiable, Equatable {
    let id: UUID
    let visitId: UUID
    /// Course.id（ローカルのUUID）。サーバー送信時は courseId から辿った rawId（元の文字列ID）を使う
    let courseId: UUID
    /// CourseSpot.id（ローカルのUUID）。サーバー送信時は spotId から辿った spotId（文字列）を使う
    let spotId: UUID
    let distanceMeters: Double
    let arrivedAt: Date
    let appVersion: String
    var isSent: Bool
    /// そのスポット（place単位）での到達順位。送信前・レスポンス未対応の間はnil
    var rank: Int?
}

extension SpotArrival {
    /// (visitId, spotId) から決定論的なidを導出する（1visit×N spotの重複を防ぐための冪等キー）
    static func makeId(visitId: UUID, spotId: UUID) -> UUID {
        CourseJSONParser.uuidFromString("\(visitId.uuidString)-\(spotId.uuidString)")
    }
}

/// サーバー送信用に、文字列IDへ解決済みの到達記録。
/// Course.rawId（未バックフィルの間はnil）が確定しないとこの形には変換できない
struct ResolvedSpotArrival {
    let id: UUID
    let visitId: UUID
    let courseRawId: String
    let spotStringId: String
    let distanceMeters: Double
    let arrivedAt: Date
    let appVersion: String
}
