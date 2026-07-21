import Foundation
import SwiftUI

// スポットフォルダのドメインモデル
struct SpotFolder: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var spotIds: [UUID]
    let createdAt: Date
    /// デフォルトフォルダ（削除不可）
    var isDefault: Bool
}

// スポットのフォルダ管理を UserDefaults で行うストア
// SpotFavoriteStore と同じパターンで実装
@Observable
final class SpotFolderStore {
    private static let key = "kokokita.spotFolders"
    private(set) var folders: [SpotFolder]

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([SpotFolder].self, from: data) {
            folders = decoded
        } else {
            folders = []
        }
        ensureDefaultFolder()
    }

    /// デフォルトフォルダ（最初の isDefault == true なもの）
    var defaultFolder: SpotFolder? { folders.first(where: { $0.isDefault }) }

    // MARK: - スポット操作

    func addSpot(_ spotId: UUID, to folderId: UUID) {
        guard let idx = folders.firstIndex(where: { $0.id == folderId }) else { return }
        guard !folders[idx].spotIds.contains(spotId) else { return }
        folders[idx].spotIds.append(spotId)
        persist()
    }

    func removeSpot(_ spotId: UUID, from folderId: UUID) {
        guard let idx = folders.firstIndex(where: { $0.id == folderId }) else { return }
        folders[idx].spotIds.removeAll { $0 == spotId }
        persist()
    }

    func toggleSpot(_ spotId: UUID, in folderId: UUID) {
        if isSpot(spotId, in: folderId) {
            removeSpot(spotId, from: folderId)
        } else {
            addSpot(spotId, to: folderId)
        }
    }

    func isSpot(_ spotId: UUID, in folderId: UUID) -> Bool {
        folders.first(where: { $0.id == folderId })?.spotIds.contains(spotId) ?? false
    }

    /// スポットが含まれているすべてのフォルダを返す
    func foldersContaining(_ spotId: UUID) -> [SpotFolder] {
        folders.filter { $0.spotIds.contains(spotId) }
    }

    // MARK: - フォルダ操作

    @discardableResult
    func createFolder(name: String) -> SpotFolder {
        let folder = SpotFolder(id: UUID(), name: name, spotIds: [], createdAt: Date(), isDefault: false)
        folders.append(folder)
        persist()
        return folder
    }

    func renameFolder(_ id: UUID, name: String) {
        guard let idx = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[idx].name = name
        persist()
    }

    /// デフォルトフォルダは削除できない
    func deleteFolder(_ id: UUID) {
        folders.removeAll { $0.id == id && !$0.isDefault }
        persist()
    }

    // MARK: - 内部

    private func ensureDefaultFolder() {
        guard !folders.contains(where: { $0.isDefault }) else { return }
        let defaultFolder = SpotFolder(
            id: UUID(),
            name: "フォルダ",
            spotIds: [],
            createdAt: Date(),
            isDefault: true
        )
        folders.insert(defaultFolder, at: 0)
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(folders) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}

// MARK: - Environment キー

private struct SpotFolderStoreKey: EnvironmentKey {
    static let defaultValue = SpotFolderStore()
}

extension EnvironmentValues {
    var spotFolderStore: SpotFolderStore {
        get { self[SpotFolderStoreKey.self] }
        set { self[SpotFolderStoreKey.self] = newValue }
    }
}
