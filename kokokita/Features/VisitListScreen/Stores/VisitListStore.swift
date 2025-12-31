import Foundation
import Observation

@MainActor
@Observable
final class VisitListStore {
    var items: [VisitAggregate] = []

    // 検索条件の復元中フラグ（didSetでの保存をスキップするため）
    private var isLoadingPrefs = false

    var labelFilters: [UUID] = [] {       // ラベルフィルタ（複数選択）
        didSet { if !isLoadingPrefs { saveFilterPrefs() } }
    }
    var groupFilters: [UUID] = [] {       // グループフィルタ（複数選択）
        didSet { if !isLoadingPrefs { saveFilterPrefs() } }
    }
    var memberFilters: [UUID] = [] {      // メンバーフィルタ（複数選択）
        didSet { if !isLoadingPrefs { saveFilterPrefs() } }
    }
    var categoryFilters: [String] = [] {  // カテゴリフィルタ（複数選択、rawValue）
        didSet { if !isLoadingPrefs { saveFilterPrefs() } }
    }
    var titleQuery: String = "" {         // タイトル部分一致
        didSet { if !isLoadingPrefs { saveFilterPrefs() } }
    }
    var dateFrom: Date? = nil {          // 範囲: 開始
        didSet { if !isLoadingPrefs { saveFilterPrefs() } }
    }
    var dateTo: Date? = nil {            // 範囲: 終了
        didSet { if !isLoadingPrefs { saveFilterPrefs() } }
    }

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

    // MARK: - Filter Persistence

    private func saveFilterPrefs() {
        let defaults = UserDefaults.standard
        defaults.set(labelFilters.map { $0.uuidString }, forKey: "home.labelFilters")
        defaults.set(groupFilters.map { $0.uuidString }, forKey: "home.groupFilters")
        defaults.set(memberFilters.map { $0.uuidString }, forKey: "home.memberFilters")
        defaults.set(categoryFilters, forKey: "home.categoryFilters")
        defaults.set(titleQuery, forKey: "home.titleQuery")
        if let dateFrom = dateFrom {
            defaults.set(dateFrom.timeIntervalSince1970, forKey: "home.dateFrom")
        } else {
            defaults.removeObject(forKey: "home.dateFrom")
        }
        if let dateTo = dateTo {
            defaults.set(dateTo.timeIntervalSince1970, forKey: "home.dateTo")
        } else {
            defaults.removeObject(forKey: "home.dateTo")
        }
    }

    private func loadFilterPrefs() {
        isLoadingPrefs = true
        defer { isLoadingPrefs = false }

        let defaults = UserDefaults.standard

        // UUID配列の復元
        if let labelStrings = defaults.stringArray(forKey: "home.labelFilters") {
            labelFilters = labelStrings.compactMap { UUID(uuidString: $0) }
        }
        if let groupStrings = defaults.stringArray(forKey: "home.groupFilters") {
            groupFilters = groupStrings.compactMap { UUID(uuidString: $0) }
        }
        if let memberStrings = defaults.stringArray(forKey: "home.memberFilters") {
            memberFilters = memberStrings.compactMap { UUID(uuidString: $0) }
        }

        // String配列の復元
        if let categories = defaults.stringArray(forKey: "home.categoryFilters") {
            categoryFilters = categories
        }

        // タイトルクエリの復元
        titleQuery = defaults.string(forKey: "home.titleQuery") ?? ""

        // 日付の復元
        if defaults.object(forKey: "home.dateFrom") != nil {
            let timestamp = defaults.double(forKey: "home.dateFrom")
            dateFrom = Date(timeIntervalSince1970: timestamp)
        }
        if defaults.object(forKey: "home.dateTo") != nil {
            let timestamp = defaults.double(forKey: "home.dateTo")
            dateTo = Date(timeIntervalSince1970: timestamp)
        }
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
        // didSetで自動的に保存される
    }

    // MARK: - Dependencies (Repository)

    private let repo: CoreDataVisitRepository

    // MARK: - Initialization

    init(repo: CoreDataVisitRepository = AppContainer.shared.repo) {
        self.repo = repo
        loadSortPref()
        loadFilterPrefs()  // 検索条件を復元
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

            // 複数選択対応のため、ラベル・グループ・メンバーフィルタはクライアントサイドで適用
            var rows = try repo.fetchAll(
                filterLabel: nil,
                filterGroup: nil,
                filterMember: nil,
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
