import Foundation

/// タクソノミー（Label/Group/Member）の一覧管理Store
/// ジェネリック実装により、3つのタクソノミータイプで共通利用
@MainActor
@Observable
final class TaxonomyListStore<T: TaxonomyTag> {

    // MARK: - State

    var items: [T] = []
    var loading = false
    var alert: String?

    // MARK: - Dependencies

    private let repository: CoreDataTaxonomyRepository

    // MARK: - Initialization

    init(repository: CoreDataTaxonomyRepository = AppContainer.shared.taxonomyRepo) {
        self.repository = repository
    }

    // MARK: - Actions

    /// アイテムをロード（フィルタリング＆ソート済み）
    func load(type: TaxonomyType) async {
        loading = true
        defer { loading = false }

        do {
            let rows: [T]
            switch type {
            case .label:
                rows = try repository.allLabels() as! [T]
            case .group:
                rows = try repository.allGroups() as! [T]
            case .member:
                rows = try repository.allMembers() as! [T]
            }

            items = TaxonomySorter.filterAndSort(rows)
        } catch {
            alert = error.localizedDescription
        }
    }

    /// 新規作成
    /// - Parameter name: 作成する名前
    /// - Returns: 成功した場合はtrue
    func create(name: String, type: TaxonomyType) -> Bool {
        // バリデーション
        guard let validName = TaxonomyValidator.validateName(name) else {
            return false
        }

        // 重複チェック
        if TaxonomyValidator.isDuplicate(validName, in: items) {
            alert = "同じ名前の\(type.displayName)が既にあります。"
            return false
        }

        do {
            let id: UUID
            switch type {
            case .label:
                id = try repository.createLabel(name: validName)
            case .group:
                id = try repository.createGroup(name: validName)
            case .member:
                id = try repository.createMember(name: validName)
            }

            // リストに追加してソート
            let newItem: T
            switch type {
            case .label:
                newItem = LabelTag(id: id, name: validName) as! T
            case .group:
                newItem = GroupTag(id: id, name: validName) as! T
            case .member:
                newItem = MemberTag(id: id, name: validName) as! T
            }

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
    ///   - type: タクソノミータイプ
    /// - Returns: 成功した場合はtrue
    func update(id: UUID, name: String, type: TaxonomyType) -> Bool {
        // バリデーション
        guard let validName = TaxonomyValidator.validateName(name) else {
            return false
        }

        do {
            switch type {
            case .label:
                try repository.renameLabel(id: id, newName: validName)
            case .group:
                try repository.renameGroup(id: id, newName: validName)
            case .member:
                try repository.renameMember(id: id, newName: validName)
            }

            // ローカルリストを更新
            if let index = items.firstIndex(where: { $0.id == id }) {
                let updatedItem: T
                switch type {
                case .label:
                    updatedItem = LabelTag(id: id, name: validName) as! T
                case .group:
                    updatedItem = GroupTag(id: id, name: validName) as! T
                case .member:
                    updatedItem = MemberTag(id: id, name: validName) as! T
                }
                items[index] = updatedItem
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
    /// - Parameters:
    ///   - id: 削除対象のID
    ///   - type: タクソノミータイプ
    /// - Returns: 成功した場合はtrue
    func delete(id: UUID, type: TaxonomyType) -> Bool {
        do {
            switch type {
            case .label:
                try repository.deleteLabel(id: id)
            case .group:
                try repository.deleteGroup(id: id)
            case .member:
                try repository.deleteMember(id: id)
            }

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

// MARK: - TaxonomyType

/// タクソノミーの種類
enum TaxonomyType {
    case label
    case group
    case member

    var displayName: String {
        switch self {
        case .label: return "ラベル"
        case .group: return "グループ"
        case .member: return "メンバー"
        }
    }
}
