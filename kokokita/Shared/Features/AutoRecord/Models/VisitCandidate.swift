import Foundation

/// 自動記録の候補データ
/// CLVisit から生成され、ユーザーが承認するまで一時保持される
struct VisitCandidate: Identifiable, Equatable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let arrivalDate: Date
    let departureDate: Date?
    let horizontalAccuracy: Double
    /// 逆ジオコーディング結果（表示直前に補完される）
    var placeName: String?
    let status: CandidateStatus
    let detectedAt: Date

    enum CandidateStatus: String {
        case pending = "pending"
        case dismissed = "dismissed"
    }

    /// 滞在時間（departureDate がある場合のみ算出）
    var stayDuration: TimeInterval? {
        guard let dep = departureDate else { return nil }
        return dep.timeIntervalSince(arrivalDate)
    }

    /// 表示用の地名（placeName が取得できない場合は座標をフォールバック表示）
    var displayName: String {
        if let name = placeName, !name.isEmpty { return name }
        let lat = String(format: "%.4f", latitude)
        let lon = String(format: "%.4f", longitude)
        return "\(lat), \(lon)"
    }
}
