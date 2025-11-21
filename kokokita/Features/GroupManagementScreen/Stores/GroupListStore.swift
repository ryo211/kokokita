import Foundation

/// グループ一覧管理Store
@MainActor
@Observable
final class GroupListStore {

    // MARK: - State

    var items: [GroupTag] = []
    var loading = false
    var alert: String?

    // MARK: - Dependencies

    private let repository: CoreDataTaxonomyRepository

    // MARK: - Initialization

    init(repository: CoreDataTaxonomyRepository = AppContainer.shared.taxonomyRepo) {
        self.repository = repository
    }

    // MARK: - Actions

    /// グループをロード（フィルタリング＆ソート済み）
    func load() async {
        loading = true
        defer { loading = false }

        do {
            let rows = try repository.allGroups()
            items = filterAndSort(rows)
        } catch {
            alert = error.localizedDescription
        }
    }

    /// 新規作成
    /// - Parameter name: 作成する名前
    /// - Returns: 成功した場合はtrue
    func create(name: String) -> Bool {
        // バリデーション
        guard let validName = GroupValidator.validateName(name) else {
            return false
        }

        // 重複チェック
        if GroupValidator.isDuplicate(validName, in: items) {
            alert = L.GroupManagement.duplicateName
            return false
        }

        do {
            let id = try repository.createGroup(name: validName)

            // リストに追加してソート
            let newItem = GroupTag(id: id, name: validName)
            items.append(newItem)
            items = sort(items)

            // 通知送信
            NotificationCenter.default.post(name: .taxonomyChanged, object: nil)

            return true
        } catch {
            alert = error.localizedDescription
            return false
        }
    }

    /// 更新
    /// - Parameters:
    ///   - id: 更新対象のID
    ///   - name: 新しい名前
    /// - Returns: 成功した場合はtrue
    func update(id: UUID, name: String) -> Bool {
        // バリデーション
        guard let validName = GroupValidator.validateName(name) else {
            return false
        }

        do {
            try repository.renameGroup(id: id, newName: validName)

            // ローカルリストを更新
            if let index = items.firstIndex(where: { $0.id == id }) {
                items[index] = GroupTag(id: id, name: validName)
            }

            // 通知送信
            NotificationCenter.default.post(name: .taxonomyChanged, object: nil)

            return true
        } catch {
            alert = error.localizedDescription
            return false
        }
    }

    /// 削除
    /// - Parameter id: 削除対象のID
    /// - Returns: 成功した場合はtrue
    func delete(id: UUID) -> Bool {
        do {
            try repository.deleteGroup(id: id)

            // ローカルリストから削除
            items.removeAll { $0.id == id }

            // 通知送信
            NotificationCenter.default.post(name: .taxonomyChanged, object: nil)

            return true
        } catch {
            alert = error.localizedDescription
            return false
        }
    }

    // MARK: - Private Helpers

    /// 空文字列を除外してソート
    private func filterAndSort(_ items: [GroupTag]) -> [GroupTag] {
        return items
            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    /// 名前でソート
    private func sort(_ items: [GroupTag]) -> [GroupTag] {
        return items.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
}
