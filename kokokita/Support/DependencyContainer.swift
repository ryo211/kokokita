//
//  DependencyContainer.swift
//  kokokita
//
//  Created by Claude on 2025/10/11.
//

import Foundation

/// 簡易DIコンテナ（依存性注入）
final class AppContainer {
    static let shared = AppContainer()

    // Repository はプロトコル型で公開（テストや差し替え容易）
    let repo: (VisitRepository & TaxonomyRepository) = CoreDataVisitRepository()

    // Rate Limiter (共有インスタンス)
    let rateLimiter = RateLimiter(minimumInterval: 0.5)

    // Services
    let loc = DefaultLocationService()
    lazy var poi: MapKitPlaceLookupService = MapKitPlaceLookupService(rateLimiter: rateLimiter)
    let integ = DefaultIntegrityService()

    private init() {}
}
