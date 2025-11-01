//
//  Visit.swift
//  kokokita
//
//  Created by 橋本遼 on 2025/09/20.
//

import Foundation

/// 訪問記録の不変データ（改ざん検出用署名付き）
struct Visit: Identifiable, Codable, Equatable {
    let id: UUID
    let timestampUTC: Date
    let latitude: Double
    let longitude: Double
    let horizontalAccuracy: Double?
    let isSimulatedBySoftware: Bool?
    let isProducedByAccessory: Bool?
    let integrity: Integrity

    struct Integrity: Codable, Equatable {
        let algo: String
        let signatureDERBase64: String
        let publicKeyRawBase64: String
        let payloadHashHex: String
        let createdAtUTC: Date
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
