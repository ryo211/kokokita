//
//  HomeViewModel.swift
//  kokokita
//
//  Created by 橋本遼 on 2025/09/20.
//

import Foundation
import Observation

// 日付グループ構造
struct DateGroup: Identifiable {
    let id: String
    let date: Date
    let items: [VisitAggregate]
}

@MainActor
@Observable
final class HomeViewModel {
    var items: [VisitAggregate] = []
    var labelFilter: UUID? = nil
    var groupFilter: UUID? = nil
    var memberFilter: UUID? = nil
    var categoryFilter: String? = nil  // カテゴリフィルタ (rawValue)
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

    // 適用中のフィルタがあるか
    var hasActiveFilters: Bool {
        return labelFilter != nil || groupFilter != nil || memberFilter != nil || categoryFilter != nil ||
               !titleQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
               dateFrom != nil || dateTo != nil
    }

    // 日付ごとにグループ化
    var groupedByDate: [DateGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: items) { item in
            calendar.startOfDay(for: item.visit.timestampUTC)
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        return grouped.map { (date, items) in
            DateGroup(
                id: dateFormatter.string(from: date),
                date: date,
                items: items.sorted { a, b in
                    sortAscending ? (a.visit.timestampUTC < b.visit.timestampUTC) : (a.visit.timestampUTC > b.visit.timestampUTC)
                }
            )
        }.sorted { a, b in
            sortAscending ? (a.date < b.date) : (a.date > b.date)
        }
    }

    // ユーザ操作用
    func clearAllFilters() {
        labelFilter = nil
        groupFilter = nil
        memberFilter = nil
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

            // メンバーフィルタ（クライアントサイド）
            if let memberFilter = memberFilter {
                rows = rows.filter { $0.details.memberIds.contains(memberFilter) }
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
            members = try repo.allMembers()
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
            self.members = try repo.allMembers()
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
