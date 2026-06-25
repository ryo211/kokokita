import Foundation

/// 自動記録の除外エリア
/// この場所の周辺（radiusMeters以内）では CLVisit を候補化しない
struct ExcludedLocation: Identifiable, Equatable {
    let id: UUID
    /// ユーザーが付けた名前（「自宅」「職場」など）。未設定の場合は座標を表示
    let label: String?
    let latitude: Double
    let longitude: Double
    /// 除外半径（メートル）
    let radiusMeters: Double
    let createdAt: Date

    var displayLabel: String {
        if let label, !label.isEmpty { return label }
        let lat = String(format: "%.4f", latitude)
        let lon = String(format: "%.4f", longitude)
        return "\(lat), \(lon)"
    }
}
