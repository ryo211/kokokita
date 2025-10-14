//
//  HomeViewModel.swift
//  kokokita
//
//  Created by 橋本遼 on 2025/09/20.
//

import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var items: [VisitAggregate] = []
    @Published var labelFilter: UUID? = nil
    @Published var groupFilter: UUID? = nil
    @Published var categoryFilter: String? = nil  // カテゴリフィルタ (rawValue)
    @Published var titleQuery: String = ""         // タイトル部分一致
    @Published var dateFrom: Date? = nil          // 範囲: 開始
    @Published var dateTo: Date? = nil            // 範囲: 終了

    @Published var labels: [LabelTag] = []
    @Published var groups: [GroupTag] = []
    @Published var alert: String?
    
    @Published var sortAscending: Bool = false {            // ★ 既定は「降順 = 最新が上」
        didSet { saveSortPref() }
    }

    private func saveSortPref() {
        UserDefaults.standard.set(sortAscending, forKey: "home.sortAscending")
    }
    private func loadSortPref() {
        sortAscending = UserDefaults.standard.bool(forKey: "home.sortAscending")
    }
    
    // 適用中のフィルタがあるか
    var hasActiveFilters: Bool {
        return labelFilter != nil || groupFilter != nil || categoryFilter != nil ||
               !titleQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
               dateFrom != nil || dateTo != nil
    }

    // ユーザ操作用
    func clearAllFilters() {
        labelFilter = nil
        groupFilter = nil
        categoryFilter = nil
        titleQuery = ""
        dateFrom = nil
        dateTo = nil
    }
    
    private let repo: VisitRepository & TaxonomyRepository
    
    init(repo: VisitRepository & TaxonomyRepository) {
        self.repo = repo
        loadSortPref()
        reload()
    }

    func reload() {
        do {
            // 「タイトル空白」は nil にして渡す
            let q = titleQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = q.isEmpty ? nil : q

            // 日付は日単位で扱いたいなら startOfDay / endOfDay+1 を使う
            let from = dateFrom.map { Calendar.current.startOfDay(for: $0) }
            let toExclusive = dateTo.map { calEndExclusive($0) }

            var rows = try repo.fetchAll(
                filterLabel: labelFilter,
                filterGroup: groupFilter,
                titleQuery: title,
                dateFrom: from,
                dateToExclusive: toExclusive
            )

            // カテゴリフィルタ（クライアントサイド）
            if let catFilter = categoryFilter {
                rows = rows.filter { $0.details.facilityCategory == catFilter }
            }

            // ★ ここでソートを一元管理（timestampUTC がない場合は適宜プロパティ名を合わせる）
            rows.sort { a, b in
                let ta = a.visit.timestampUTC
                let tb = b.visit.timestampUTC
                return sortAscending ? (ta < tb) : (ta > tb)
            }
            items = rows
            
            labels = try repo.allLabels()
            groups = try repo.allGroups()
        } catch {
            alert = error.localizedDescription
        }
    }
    private func calEndExclusive(_ d: Date) -> Date {
        let cal = Calendar.current
        let endOfDay = cal.date(bySettingHour: 23, minute: 59, second: 59, of: d) ?? d
        return cal.date(byAdding: .second, value: 1, to: endOfDay) ?? endOfDay
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
    
    @MainActor
    func loadTaxonomy() {
        do {
            self.labels = try repo.allLabels()
            self.groups = try repo.allGroups()
        } catch {
            self.alert = error.localizedDescription
        }
    }

    @MainActor
    func reloadTaxonomyThenData() async {
        loadTaxonomy()
        await reload()
    }

}
