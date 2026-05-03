import Foundation
import SwiftUI

// スポットのお気に入り状態を UserDefaults で管理するストア
// Core Data マイグレーション不要のシンプルな永続化
@Observable
final class SpotFavoriteStore {
    private let key = "kokokita.favoriteSpotIds"

    /// お気に入りのスポット ID セット
    private(set) var favoriteSpotIds: Set<UUID>

    init() {
        if let data = UserDefaults.standard.data(forKey: "kokokita.favoriteSpotIds"),
           let ids = try? JSONDecoder().decode(Set<UUID>.self, from: data) {
            favoriteSpotIds = ids
        } else {
            favoriteSpotIds = []
        }
    }

    /// お気に入りを切り替える
    func toggle(_ spotId: UUID) {
        if favoriteSpotIds.contains(spotId) {
            favoriteSpotIds.remove(spotId)
        } else {
            favoriteSpotIds.insert(spotId)
        }
        persist()
    }

    /// お気に入りかどうかを返す
    func isFavorite(_ spotId: UUID) -> Bool {
        favoriteSpotIds.contains(spotId)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(favoriteSpotIds) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

// MARK: - Environment キー

private struct SpotFavoriteStoreKey: EnvironmentKey {
    static let defaultValue = SpotFavoriteStore()
}

extension EnvironmentValues {
    var spotFavoriteStore: SpotFavoriteStore {
        get { self[SpotFavoriteStoreKey.self] }
        set { self[SpotFavoriteStoreKey.self] = newValue }
    }
}
