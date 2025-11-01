import Foundation

/// メンバー一覧管理Store
@MainActor
@Observable
final class MemberListStore {

    // MARK: - State

    var items: [MemberTag] = []
    var loading = false
    var alert: String?

    // MARK: - Dependencies

    private let repository: CoreDataTaxonomyRepository

    // MARK: - Initialization

    init(repository: CoreDataTaxonomyRepository = AppContainer.shared.taxonomyRepo) {
        self.repository = repository
    }

    // MARK: - Actions

    /// メンバーをロード（フィルタリング＆ソート済み）
    func load() async {
        loading = true
        defer { loading = false }

        do {
            let rows = try repository.allMembers()
            items = TaxonomySorter.filterAndSort(rows)
        } catch {
            alert = error.localizedDescription
        }
    }

    /// 新規作成
    /// - Parameter name: 作成する名前
    /// - Returns: 成功した場合はtrue
    func create(name: String) -> Bool {
        // バリデーション
        guard let validName = TaxonomyValidator.validateName(name) else {
            return false
        }

        // 重複チェック
        if TaxonomyValidator.isDuplicate(validName, in: items) {
            alert = "同じ名前のメンバーが既にあります。"
            return false
        }

        do {
            let id = try repository.createMember(name: validName)

            // リストに追加してソート
            let newItem = MemberTag(id: id, name: validName)
            items.append(newItem)
            items = TaxonomySorter.sortByName(items)

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
        guard let validName = TaxonomyValidator.validateName(name) else {
            return false
        }

        do {
            try repository.renameMember(id: id, newName: validName)

            // ローカルリストを更新
            if let index = items.firstIndex(where: { $0.id == id }) {
                items[index] = MemberTag(id: id, name: validName)
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
            try repository.deleteMember(id: id)

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
}
