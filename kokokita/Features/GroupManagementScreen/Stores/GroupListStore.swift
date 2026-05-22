import Foundation

/// グループ一覧管理Store
@MainActor
@Observable
final class GroupListStore {

    // MARK: - State

    var items: [GroupTag] = []
    var visitCounts: [UUID: Int] = [:]
    /// 各旅行の（最古記録日, 最新記録日）
    var dateRanges: [UUID: (earliest: Date, latest: Date)] = [:]
    /// 各旅行に関連する記録に紐づくメンバー名一覧（名前昇順）
    var tripMembers: [UUID: [String]] = [:]
    var loading = false
    var alert: String?

    // MARK: - Dependencies

    private let repository: CoreDataTaxonomyRepository
    private let visitRepository: CoreDataVisitRepository

    // MARK: - Notification Observer
    // iOS 9以降では、オブザーバーはオブジェクト解放時に自動的に登録解除される

    private var notificationObserver: Any?

    // MARK: - Initialization

    init(repository: CoreDataTaxonomyRepository = AppContainer.shared.taxonomyRepo,
         visitRepository: CoreDataVisitRepository = AppContainer.shared.repo) {
        self.repository = repository
        self.visitRepository = visitRepository

        // 他の画面からのタクソノミー変更通知を監視してリロード
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .taxonomyChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.load()
            }
        }
    }

    // MARK: - Actions

    /// グループをロード（フィルタリング＆ソート済み）
    func load() async {
        loading = true
        defer { loading = false }

        do {
            let rows = try repository.allGroups()
            items = filterAndSort(rows)

            // メンバー名解決用マップ（全件を一度だけ取得）
            let allMembers = try repository.allMembers()
            let memberNameMap = Dictionary(uniqueKeysWithValues: allMembers.map { ($0.id, $0.name) })

            // 各グループの訪問記録数・日付範囲・同行メンバーを取得
            var counts: [UUID: Int] = [:]
            var ranges: [UUID: (earliest: Date, latest: Date)] = [:]
            var members: [UUID: [String]] = [:]
            for group in items {
                let visits = try visitRepository.fetchAll(
                    filterLabel: nil,
                    filterGroup: group.id,
                    filterMember: nil,
                    titleQuery: nil,
                    dateFrom: nil,
                    dateToExclusive: nil
                )
                counts[group.id] = visits.count
                let dates = visits.map { $0.visit.timestampUTC }
                if let earliest = dates.min(), let latest = dates.max() {
                    ranges[group.id] = (earliest: earliest, latest: latest)
                }
                // 全記録からメンバーIDを収集して重複排除・名前解決
                let memberIds = Set(visits.flatMap { $0.details.memberIds })
                let names = memberIds.compactMap { memberNameMap[$0] }.sorted()
                if !names.isEmpty {
                    members[group.id] = names
                }
            }
            visitCounts = counts
            dateRanges = ranges
            tripMembers = members

            // 最新訪問日が新しい順にソート（記録なしは末尾）
            items.sort {
                switch (ranges[$0.id]?.latest, ranges[$1.id]?.latest) {
                case let (l?, r?): return l > r
                case (_?, nil):   return true
                case (nil, _?):   return false
                default:          return $0.name.localizedCompare($1.name) == .orderedAscending
                }
            }
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
