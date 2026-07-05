import Foundation

/// 課金商品のID定義
enum PremiumProduct {
    static let monthlyId  = "jp.kokokita.premium.monthly"
    static let yearlyId   = "jp.kokokita.premium.yearly"
    static let lifetimeId = "jp.kokokita.premium.lifetime"

    static let allProductIds: Set<String> = [monthlyId, yearlyId, lifetimeId]

    /// ペイウォールでの表示順
    static func sortOrder(_ productId: String) -> Int {
        switch productId {
        case monthlyId:  return 0
        case yearlyId:   return 1
        case lifetimeId: return 2
        default:         return 99
        }
    }

    /// プレミアム権利を持つ商品かどうか
    static func isPremiumProduct(id: String) -> Bool {
        allProductIds.contains(id)
    }
}
