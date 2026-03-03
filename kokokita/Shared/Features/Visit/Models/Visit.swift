import Foundation

/// 訪問記録の不変データ（改ざん検出用署名付き）
/// 後付け記録（isManualEntry == true）の場合は署名なし（integrity == nil）
struct Visit: Identifiable, Codable, Equatable {
    let id: UUID
    let timestampUTC: Date
    let latitude: Double
    let longitude: Double
    let horizontalAccuracy: Double?
    let isSimulatedBySoftware: Bool?
    let isProducedByAccessory: Bool?
    let integrity: Integrity?
    let isManualEntry: Bool

    /// 改ざん検出用の署名情報
    struct Integrity: Codable, Equatable {
        let algo: String
        let signatureDERBase64: String
        let publicKeyRawBase64: String
        let payloadHashHex: String
        let createdAtUTC: Date
    }

    /// 通常記録用イニシャライザ（署名あり）
    init(
        id: UUID,
        timestampUTC: Date,
        latitude: Double,
        longitude: Double,
        horizontalAccuracy: Double?,
        isSimulatedBySoftware: Bool?,
        isProducedByAccessory: Bool?,
        integrity: Integrity
    ) {
        self.id = id
        self.timestampUTC = timestampUTC
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracy = horizontalAccuracy
        self.isSimulatedBySoftware = isSimulatedBySoftware
        self.isProducedByAccessory = isProducedByAccessory
        self.integrity = integrity
        self.isManualEntry = false
    }

    /// 後付け記録用イニシャライザ（署名なし）
    init(
        id: UUID,
        timestampUTC: Date,
        latitude: Double,
        longitude: Double,
        horizontalAccuracy: Double?
    ) {
        self.id = id
        self.timestampUTC = timestampUTC
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracy = horizontalAccuracy
        self.isSimulatedBySoftware = nil
        self.isProducedByAccessory = nil
        self.integrity = nil
        self.isManualEntry = true
    }

    /// フルイニシャライザ（データ復元用）
    init(
        id: UUID,
        timestampUTC: Date,
        latitude: Double,
        longitude: Double,
        horizontalAccuracy: Double?,
        isSimulatedBySoftware: Bool?,
        isProducedByAccessory: Bool?,
        integrity: Integrity?,
        isManualEntry: Bool
    ) {
        self.id = id
        self.timestampUTC = timestampUTC
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracy = horizontalAccuracy
        self.isSimulatedBySoftware = isSimulatedBySoftware
        self.isProducedByAccessory = isProducedByAccessory
        self.integrity = integrity
        self.isManualEntry = isManualEntry
    }
}

/// 位置情報のソースフラグ（偽装/外部アクセサリ検知）
public struct LocationSourceFlags: Codable, Equatable {
    public let isSimulatedBySoftware: Bool?
    public let isProducedByAccessory: Bool?

    public init(isSimulatedBySoftware: Bool?, isProducedByAccessory: Bool?) {
        self.isSimulatedBySoftware = isSimulatedBySoftware
        self.isProducedByAccessory = isProducedByAccessory
    }
}
