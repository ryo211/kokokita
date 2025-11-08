import Foundation
import Observation

@MainActor
@Observable
final class VisitListStore {
    var items: [VisitAggregate] = []
    var labelFilters: [UUID] = []       // ラベルフィルタ（複数選択）
    var groupFilters: [UUID] = []       // グループフィルタ（複数選択）
    var memberFilters: [UUID] = []      // メンバーフィルタ（複数選択）
    var categoryFilters: [String] = []  // カテゴリフィルタ（複数選択、rawValue）
    var titleQuery: String = ""         // タイトル部分一致
    var dateFrom: Date? = nil          // 範囲: 開始
    var dateTo: Date? = nil            // 範囲: 終了

    var labels: [LabelTag] = []
    var groups: [GroupTag] = []
    var members: [MemberTag] = []
    var alert: String?

    var sortAscending: Bool = false {            // ★ 既定は「降順 = 最新が上」
        didSet { saveSortPref() }
    }

    private func saveSortPref() {
        UserDefaults.standard.set(sortAscending, forKey: "home.sortAscending")
    }
    private func loadSortPref() {
        sortAscending = UserDefaults.standard.bool(forKey: "home.sortAscending")
    }

    // MARK: - Dependencies (Logic)
    
    private let filter = VisitFilter()
    private let sorter = VisitSorter()
    private let grouper = VisitGrouper()
    private let dateHelper = DateHelper()

    // MARK: - Computed Properties (Pure Functions)

    /// 適用中のフィルタがあるか
    var hasActiveFilters: Bool {
        return filter.hasActiveFilters(currentCriteria)
    }

    /// 日付ごとにグループ化
    var groupedByDate: [DateGroup] {
        return grouper.groupByDate(items, ascending: sortAscending)
    }

    /// 現在のフィルタ条件
    private var currentCriteria: FilterCriteria {
        FilterCriteria(
            labelIds: labelFilters,
            groupIds: groupFilters,
            memberIds: memberFilters,
            categories: categoryFilters,
            titleQuery: titleQuery,
            dateFrom: dateFrom,
            dateTo: dateTo
        )
    }

    // MARK: - User Actions

    func clearAllFilters() {
        labelFilters = []
        groupFilters = []
        memberFilters = []
        categoryFilters = []
        titleQuery = ""
        dateFrom = nil
        dateTo = nil
    }

    // MARK: - Dependencies (Repository)

    private let repo: CoreDataVisitRepository

    // MARK: - Initialization

    init(repo: CoreDataVisitRepository = AppContainer.shared.repo) {
        self.repo = repo
        loadSortPref()
        reload()
    }

    // MARK: - Data Loading (Side Effects)

    func reload() {
        do {
            // 「タイトル空白」は nil にして渡す
            let q = titleQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = q.isEmpty ? nil : q

            // 日付は日単位で扱いたいなら startOfDay / endOfDay+1 を使う
            let from = dateFrom.map { dateHelper.startOfDay($0) }
            let toExclusive = dateTo.map { dateHelper.calculateEndExclusive($0) }

            // 複数選択対応のため、ラベル・グループフィルタはクライアントサイドで適用
            var rows = try repo.fetchAll(
                filterLabel: nil,
                filterGroup: nil,
                titleQuery: title,
                dateFrom: from,
                dateToExclusive: toExclusive
            )

            // クライアントサイドフィルタ適用（ラベル、グループ、カテゴリ、メンバー）
            rows = filter.applyClientSideFilters(rows, criteria: currentCriteria)

            // ソート適用
            items = sorter.sort(rows, ascending: sortAscending)

            labels = try repo.allLabels()
            groups = try repo.allGroups()
            members = try repo.allMembers()
        } catch {
            alert = error.localizedDescription
        }
    }

    func delete(id: UUID) {
        do { try repo.delete(id: id); reload() }
        catch { alert = error.localizedDescription }
    }

    func applyAndReload() {
        reload()
    }

    func toggleSort() {
        sortAscending.toggle()
        reload()
    }

    func loadTaxonomy() {
        do {
            self.labels = try repo.allLabels()
            self.groups = try repo.allGroups()
            self.members = try repo.allMembers()
        } catch {
            self.alert = error.localizedDescription
        }
    }

    func reloadTaxonomyThenData() async {
        loadTaxonomy()
        reload()
    }

}
