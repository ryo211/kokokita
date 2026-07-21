import Foundation
import SwiftUI

// コースのお気に入り状態を UserDefaults で管理するストア
// 追加順を保持するため Set ではなく配列で管理する
@Observable
final class CourseFavoriteStore {
    private let key = "kokokita.favoriteCourseIds"

    /// お気に入りのコース ID（追加した順、末尾が最新）
    private(set) var orderedFavoriteIds: [UUID]

    init() {
        // [UUID] として読み込む（旧 Set<UUID> も JSON 配列形式なので互換）
        if let data = UserDefaults.standard.data(forKey: "kokokita.favoriteCourseIds"),
           let ids = try? JSONDecoder().decode([UUID].self, from: data) {
            orderedFavoriteIds = ids
        } else {
            orderedFavoriteIds = []
        }
    }

    /// お気に入りを切り替える（追加時は末尾に追加）
    func toggle(_ courseId: UUID) {
        if let index = orderedFavoriteIds.firstIndex(of: courseId) {
            orderedFavoriteIds.remove(at: index)
        } else {
            orderedFavoriteIds.append(courseId)
        }
        persist()
    }

    /// お気に入りかどうかを返す
    func isFavorite(_ courseId: UUID) -> Bool {
        orderedFavoriteIds.contains(courseId)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(orderedFavoriteIds) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

// MARK: - Environment キー

private struct CourseFavoriteStoreKey: EnvironmentKey {
    static let defaultValue = CourseFavoriteStore()
}

extension EnvironmentValues {
    var courseFavoriteStore: CourseFavoriteStore {
        get { self[CourseFavoriteStoreKey.self] }
        set { self[CourseFavoriteStoreKey.self] = newValue }
    }
}
