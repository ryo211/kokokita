import SwiftUI
import MapKit

struct HomeFilterHeader: View {
    @Bindable var store: VisitListStore
    var onTapSearch: () -> Void

    private var vm: VisitListStore { store }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                // 検索ボタン（左側に移動）
                Button(action: onTapSearch) {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                        .foregroundStyle(Color.blue)
                }
                .buttonStyle(.plain)

                // 件数表示
                HStack(spacing: 4) {
                    Text("\(vm.items.count)")
                        .font(.body.bold())
                        .foregroundStyle(Color.blue)
                    Text(L.Home.itemsCount)
                        .font(.subheadline)
                        .foregroundStyle(Color.blue)
                }

                Spacer()

                // ソートボタン（右側）
                Button {
                    vm.toggleSort()
                } label: {
                    // 降順（最新が上）がデフォ。アイコンと説明を状態で出し分け。
                    HStack(spacing: 6) {
                        Text(vm.sortAscending ? L.SearchFilter.sortOldest : L.SearchFilter.sortNewest)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Image(systemName: vm.sortAscending ? "chevron.up"
                                                           : "chevron.down")
                            .font(.system(size: 12))
                    }
                }
                .buttonStyle(.plain)
            }

            // 1) キーワード
            if !vm.titleQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                FlowRow(spacing: 6, rowSpacing: 6) {
                    Chip(vm.titleQuery, kind: .keyword) {
                        vm.titleQuery = ""
                        vm.reload()
                    }
                }
            }

            // 2) 期間
            if vm.dateFrom != nil || vm.dateTo != nil {
                let label = dateRangeText(from: vm.dateFrom, to: vm.dateTo)
                FlowRow(spacing: 6, rowSpacing: 6) {
                    Chip(label, kind: .period) {
                        vm.dateFrom = nil; vm.dateTo = nil
                        vm.reload()
                    }
                }
            }

            // 3) ラベル（複数）
            if !vm.labelFilters.isEmpty {
                let lmap = Dictionary(uniqueKeysWithValues: vm.labels.map { ($0.id, $0.name) })
                FlowRow(spacing: 6, rowSpacing: 6) {
                    ForEach(vm.labelFilters, id: \.self) { lid in
                        if let name = lmap[lid]?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                            Chip(name, kind: .label) {
                                vm.labelFilters.removeAll { $0 == lid }
                                vm.reload()
                            }
                        }
                    }
                }
            }

            // 4) グループ（複数）
            if !vm.groupFilters.isEmpty {
                let gmap = Dictionary(uniqueKeysWithValues: vm.groups.map { ($0.id, $0.name) })
                FlowRow(spacing: 6, rowSpacing: 6) {
                    ForEach(vm.groupFilters, id: \.self) { gid in
                        if let name = gmap[gid]?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                            Chip(name, kind: .group) {
                                vm.groupFilters.removeAll { $0 == gid }
                                vm.reload()
                            }
                        }
                    }
                }
            }

            // 5) メンバー（複数）
            if !vm.memberFilters.isEmpty {
                let mmap = Dictionary(uniqueKeysWithValues: vm.members.map { ($0.id, $0.name) })
                FlowRow(spacing: 6, rowSpacing: 6) {
                    ForEach(vm.memberFilters, id: \.self) { mid in
                        if let name = mmap[mid]?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                            Chip(name, kind: .member) {
                                vm.memberFilters.removeAll { $0 == mid }
                                vm.reload()
                            }
                        }
                    }
                }
            }

            // 6) カテゴリ（複数）
            if !vm.categoryFilters.isEmpty {
                FlowRow(spacing: 6, rowSpacing: 6) {
                    ForEach(vm.categoryFilters, id: \.self) { catRaw in
                        let category = MKPointOfInterestCategory(rawValue: catRaw)
                        let name = category.localizedName
                        Chip(name, kind: .category) {
                            vm.categoryFilters.removeAll { $0 == catRaw }
                            vm.reload()
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.thinMaterial)
    }

    private func dateRangeText(from: Date?, to: Date?) -> String {
        let f = AppDateFormatters.filterDate
        switch (from, to) {
        case let (fD?, tD?): return "\(f.string(from: fD)) 〜 \(f.string(from: tD))"
        case let (fD?, nil): return "\(f.string(from: fD)) 〜"
        case let (nil, tD?): return "〜 \(f.string(from: tD))"
        default: return ""
        }
    }
}
