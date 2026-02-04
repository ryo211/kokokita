import SwiftUI
import MapKit

struct HomeFilterHeader: View {
    @Bindable var store: VisitListStore
    var displayMode: VisitListDisplayMode
    var onTapSearch: () -> Void
    var onToggleDisplayMode: (VisitListDisplayMode) -> Void

    private var vm: VisitListStore { store }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                // 検索ボタン（Liquid Glass風の円形ボタン）
                Button(action: onTapSearch) {
                    Image(systemName: "magnifyingglass")
                        .font(.body)
                        .foregroundStyle(Color.white)
                        .frame(width: 40, height: 40)
                        .background(
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.blue.opacity(0.95),
                                                Color.blue.opacity(0.75)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.25),
                                                        Color.clear
                                                    ],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                    }
                                    .shadow(color: Color.blue.opacity(0.35), radius: 8, x: 0, y: 2)
                                    .shadow(color: Color.blue.opacity(0.15), radius: 3, x: 0, y: 1)
                            }
                        )
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

                // 右寄せ: 一覧/地図/カレンダー切り替えボタン
                modeToggleButton
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
                let lColorMap = vm.labels.colorMap
                FlowRow(spacing: 6, rowSpacing: 6) {
                    ForEach(vm.labelFilters, id: \.self) { lid in
                        if let name = lmap[lid]?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                            Chip(name, kind: .label, colorDot: lColorMap[name]) {
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

    // MARK: - Mode Toggle Button (Liquid Glass Style)

    private var modeToggleButton: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景コンテナ（Liquid glass）
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.15),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.25),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
                    .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)

                // スライディングインジケーター（ヌルッと動く部分）
                let buttonWidth = (geometry.size.width - 8) / 3
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.accentColor.opacity(0.15),
                                        Color.accentColor.opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.accentColor.opacity(0.3),
                                        Color.accentColor.opacity(0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .frame(width: buttonWidth, height: geometry.size.height - 8)
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                    .offset(x: indicatorOffset(buttonWidth: buttonWidth))
                    .animation(.interpolatingSpring(stiffness: 150, damping: 18), value: displayMode)

                // ボタンラベル
                HStack(spacing: 0) {
                    // 一覧ボタン
                    Button {
                        onToggleDisplayMode(.list)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 11))
                            Text(L.Home.modeList)
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(displayMode == .list ? Color.accentColor : Color.primary.opacity(0.5))
                        .frame(width: buttonWidth)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // 地図ボタン
                    Button {
                        onToggleDisplayMode(.map)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "map")
                                .font(.system(size: 11))
                            Text(L.Home.modeMap)
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(displayMode == .map ? Color.accentColor : Color.primary.opacity(0.5))
                        .frame(width: buttonWidth)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // カレンダーボタン
                    Button {
                        onToggleDisplayMode(.calendar)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11))
                            Text(L.Home.modeCalendar)
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(displayMode == .calendar ? Color.accentColor : Color.primary.opacity(0.5))
                        .frame(width: buttonWidth)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(3)
            }
        }
        .frame(width: 200, height: 36)
    }

    private func indicatorOffset(buttonWidth: CGFloat) -> CGFloat {
        switch displayMode {
        case .list: return 4
        case .map: return buttonWidth + 4
        case .calendar: return buttonWidth * 2 + 4
        }
    }
}
