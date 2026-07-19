import Foundation

/// 課金商品のID定義
enum PremiumProduct {
    static let monthlyId  = "jp.kokokita.premium.monthly"
    static let lifetimeId = "jp.kokokita.premium.lifetime"

    static let allProductIds: Set<String> = [monthlyId, lifetimeId]

    /// ペイウォールでの表示順
    static func sortOrder(_ productId: String) -> Int {
        switch productId {
        case monthlyId:  return 0
        case lifetimeId: return 1
        default:         return 99
        }
    }

    /// Premium権利を持つ商品かどうか
    static func isPremiumProduct(id: String) -> Bool {
        allProductIds.contains(id)
    }
}
