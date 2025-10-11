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

    // Services
    let loc = DefaultLocationService()
    let poi = MapKitPlaceLookupService()
    let integ = DefaultIntegrityService()

    private init() {}
}
