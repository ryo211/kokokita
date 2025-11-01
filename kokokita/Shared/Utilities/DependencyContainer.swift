import Foundation

/// 簡易DIコンテナ（依存性注入）
final class AppContainer {
    static let shared = AppContainer()

    // Repository（具体的な実装に直接依存）
    let repo = CoreDataVisitRepository()
    let taxonomyRepo = CoreDataTaxonomyRepository()

    // Rate Limiter (共有インスタンス)
    let rateLimiter = RateLimiter(minimumInterval: 0.5)

    // Services（具体的な実装に直接依存）
    let loc = DefaultLocationService()
    lazy var poi: MapKitPlaceLookupService = MapKitPlaceLookupService(rateLimiter: rateLimiter)
    let integ = DefaultIntegrityService()

    private init() {}
}
