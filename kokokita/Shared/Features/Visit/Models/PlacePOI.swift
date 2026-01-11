import Foundation
import MapKit

/// 周辺施設（POI）データ
public struct PlacePOI: Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let category: String?
    public let address: String?
    public let phone: String?
    public let poiCategoryRaw: String?

    public init(
        id: UUID = UUID(),
        name: String,
        category: String? = nil,
        address: String? = nil,
        phone: String? = nil,
        poiCategoryRaw: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.address = address
        self.phone = phone
        self.poiCategoryRaw = poiCategoryRaw
    }

    /// MKPointOfInterestCategoryに変換
    public var poiCategory: MKPointOfInterestCategory? {
        guard let raw = poiCategoryRaw else { return nil }
        return MKPointOfInterestCategory(rawValue: raw)
    }

    /// ココカモの3分類カテゴリ
    public var kkCategory: KKCategory {
        poiCategory?.kkCategory ?? .other
    }
}
