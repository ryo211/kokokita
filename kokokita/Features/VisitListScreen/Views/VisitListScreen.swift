import SwiftUI
import CoreLocation

enum VisitListDisplayMode {
    case list
    case map
    case calendar
}

struct VisitListScreen: View {
    @Environment(AppUIState.self) private var ui
    @State private var router = NavigationRouter()
    @State private var store = VisitListStore(repo: AppContainer.shared.repo)

    @State private var pendingDeleteId: UUID? = nil
    @State private var showDeleteConfirm = false

    @State private var showSearchSheet = false
    @State private var showManualEntrySheet = false

    @State private var editingTarget: VisitAggregate? = nil

    @State private var displayMode: VisitListDisplayMode = .list
    @State private var selectedMapItemId: UUID? = nil
    @State private var detailSheetItemId: UUID? = nil
    @State private var mapSheetHeight: CGFloat = 0
    @State private var selectedDate: Date? = nil
    @State private var calendarSelectedVisitId: UUID? = nil

    // 名前辞書（型を固定して軽くする）
    private var labelMap: [UUID: String] { store.labels.nameMap }
    private var groupMap: [UUID: String] { store.groups.nameMap }
    private var memberMap: [UUID: String] { store.members.nameMap }

    /// ラベル名→色のマップ
    private var labelColorMap: [String: Color] { store.labels.colorMap }

    // カレンダー表示用：日付ごとの記録タイトルマップ
    private var visitsByDateMap: [Date: [String]] {
        var map: [Date: [String]] = [:]
        for group in store.groupedByDate {
            let date = Calendar.current.startOfDay(for: group.date)
            let titles = group.items.map { agg in
                if let title = agg.details.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
                    return title
                }
                if let facility = agg.details.facilityName?.trimmingCharacters(in: .whitespacesAndNewlines), !facility.isEmpty {
                    return facility
                }
                return L.Home.noTitle
            }
            map[date] = titles
        }
        return map
    }

    // カレンダー表示用：日付ごとの VisitAggregate マップ
    private var aggregatesByDateMap: [Date: [VisitAggregate]] {
        var map: [Date: [VisitAggregate]] = [:]
        for group in store.groupedByDate {
            let date = Calendar.current.startOfDay(for: group.date)
            map[date] = group.items
        }
        return map
    }

    var body: some View {
        mainContent
            .environment(router)
            .sheet(item: $editingTarget) { agg in
                editSheet(for: agg)
            }
            .sheet(item: detailSheetBinding) { agg in
                detailSheet(for: agg)
            }
    }

    // MARK: - List（分離して軽く）
    @ViewBuilder
    private func listContent() -> some View {
        ZStack(alignment: .top) {
            Group {
                if store.items.isEmpty {
                    // 空の状態UI
                    emptyStateView
                } else {
                    actualListView
                }
            }

            // 上部のボタン行（左: 追加ボタン、右: ソートボタン）
            HStack {
                // 後付け記録追加ボタン（左上）
                addManualEntryButton
                    .padding(.leading, 16)

                Spacer()

                // ソートボタン（リスト右上に固定表示）
                if !store.items.isEmpty {
                    sortButton
                        .padding(.trailing, 16)
                }
            }
            .padding(.top, 8)
        }
        .task { store.reload() }
        .onReceive(NotificationCenter.default.publisher(for: .visitsChanged)) { _ in
            Task { store.reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .taxonomyChanged)) { _ in
            Task { await store.reloadTaxonomyThenData() }
        }
    }

    // ソートボタン（Liquid Glass風カプセル）
    private var sortButton: some View {
        Button {
            store.toggleSort()
        } label: {
            HStack(spacing: 4) {
                Text(store.sortAscending ? L.SearchFilter.sortOldest : L.SearchFilter.sortNewest)
                    .font(.system(size: 11, weight: .medium))
                Image(systemName: store.sortAscending ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10))
            }
            .foregroundStyle(Color.primary.opacity(0.6))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                ZStack {
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule(style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.08),
                                            Color.white.opacity(0.02)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .overlay {
                            Capsule(style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.15),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        }
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 1)
                }
            )
        }
        .buttonStyle(.plain)
    }

    // 後付け記録追加ボタン（Liquid Glass風カプセル）
    private var addManualEntryButton: some View {
        Button {
            showManualEntrySheet = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                Text(L.ManualEntry.title)
                    .font(.system(size: 11, weight: .medium))
                Image(systemName: "wrench.adjustable.fill")
                    .font(.system(size: 10))
            }
            .foregroundStyle(Color.orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                ZStack {
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule(style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.orange.opacity(0.12),
                                            Color.orange.opacity(0.04)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .overlay {
                            Capsule(style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.orange.opacity(0.3),
                                            Color.orange.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        }
                        .shadow(color: Color.orange.opacity(0.15), radius: 4, x: 0, y: 1)
                }
            )
        }
        .buttonStyle(.plain)
    }

    // リスト表示本体（型推論を軽くするため分離）
    private var actualListView: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(store.groupedByDate) { group in
                    Section {
                        ForEach(group.items) { agg in
                            listRowView(for: agg)
                        }
                    } header: {
                        Text(formatDateHeader(group.date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .textCase(nil)
                    }
                    .id(Calendar.current.startOfDay(for: group.date))
                }
            }
            .listStyle(.plain)
            .onChange(of: selectedDate) { _, newDate in
                if let date = newDate {
                    withAnimation {
                        proxy.scrollTo(date, anchor: .top)
                    }
                    selectedDate = nil
                }
            }
        }
        .alert(
            L.Home.deleteConfirmTitle,
            isPresented: Binding(
                get: { pendingDeleteId != nil },
                set: { if !$0 { pendingDeleteId = nil } }
            )
        ) {
            Button(L.Common.delete, role: .destructive) {
                if let id = pendingDeleteId {
                    withAnimation {
                        store.delete(id: id)
                    }
                }
                pendingDeleteId = nil
            }
            Button(L.Common.cancel, role: .cancel) {
                pendingDeleteId = nil
            }
        } message: {
            Text(L.Home.deleteConfirmMessage)
        }
    }

    // 各リスト行のビュー（さらに分離）
    @ViewBuilder
    private func listRowView(for agg: VisitAggregate) -> some View {
        NavigationLink {
            VisitDetailScreen(
                data: toDetailData(agg),
                visitId: agg.id,
                onBack: {},
                onEdit: { editingTarget = agg },
                onShare: { /* 共有導線をここに（必要なら）*/ },
                onDelete: {
                    withAnimation {
                        store.delete(id: agg.id)
                    }
                },
                onUpdate: {
                    Task { store.reload() }
                },
                onMapTap: {
                    displayMode = .map
                    selectedMapItemId = agg.id
                }
            )
        } label: {
            VisitListRow(agg: agg, labelMap: labelMap, groupMap: groupMap, memberMap: memberMap, labelColorMap: labelColorMap)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button() {
                pendingDeleteId = agg.id
                showDeleteConfirm = true
            } label: {
                Label(L.Common.delete, systemImage: "trash")
            }
            .tint(.red)
        }
        .listRowBackground(
            Group {
                if pendingDeleteId == agg.id && showDeleteConfirm {
                    // 削除確認時: 薄い赤背景
                    LinearGradient(
                        colors: [
                            Color.red.opacity(0.08),
                            Color.red.opacity(0.04)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                } else if isWithin24Hours(agg.visit.timestampUTC) {
                    // 直近24時間の記録: 非常に控えめな青色背景
                    Color.accentColor.opacity(0.03)
                } else {
                    Color.clear
                }
            }
        )
    }

    // MARK: - Main Content

    private var mainContent: some View {
        NavigationStack {
            contentStack
        }
        .alert(
            item: Binding(
                get: { store.alert.map { AlertMsg(id: UUID(), text: $0) } },
                set: { _ in store.alert = nil }
            )
        ) { msg in
            Alert(title: Text(L.Common.error),
                  message: Text(msg.text),
                  dismissButton: .default(Text(L.Common.ok)))
        }
        .navigationTitle(L.Home.title)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: selectedMapItemId) { _, newValue in
            if newValue == nil {
                mapSheetHeight = 0
            }
            // 地図シートの表示状態をAppUIStateに反映
            ui.isMapSheetVisible = (newValue != nil && displayMode == .map)
        }
        // 他タブからの地図フォーカスリクエストを処理
        .onChange(of: ui.mapFocusVisitId) { _, newId in
            guard let visitId = newId else { return }
            // リクエストを消費
            ui.mapFocusVisitId = nil
            displayMode = .map
            selectedMapItemId = visitId
        }
        .onChange(of: displayMode) {
            mapSheetHeight = 0
            if displayMode == .map {
                // 地図に戻った時、選択中のアイテムがあればシート表示状態を復元
                ui.isMapSheetVisible = (selectedMapItemId != nil)
            } else {
                ui.isMapSheetVisible = false
            }
            // カレンダーモードから離れた時はパネル非表示状態にリセット
            if displayMode != .calendar {
                ui.isCalendarVisible = false
            }
        }
    }
    
    private var contentStack: some View {
        VStack(spacing: 0) {
            HomeFilterHeader(
                store: store,
                displayMode: displayMode,
                onTapSearch: {
                    showSearchSheet = true
                },
                onToggleDisplayMode: { newMode in
                    displayMode = newMode
                }
            )
            .sheet(isPresented: $showSearchSheet) {
                NavigationStack { SearchFilterSheet(store: store) { showSearchSheet = false } }
                .iPadSheetSize()
            }
            .sheet(isPresented: $showManualEntrySheet) {
                ManualEntryScreen()
                    .iPadSheetSize()
            }

            // 表示モードで切り替え
            switch displayMode {
            case .list:
                listContent()
            case .map:
                mapContent()
            case .calendar:
                calendarContent()
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { calendarSelectedVisitId != nil },
            set: { if !$0 { calendarSelectedVisitId = nil } }
        )) {
            if let agg = calendarSelectedVisitId.flatMap({ id in store.items.first(where: { $0.id == id }) }) {
                VisitDetailScreen(
                    data: toDetailData(agg),
                    visitId: agg.id,
                    onBack: {},
                    onEdit: { editingTarget = agg },
                    onShare: {},
                    onDelete: {
                        withAnimation {
                            store.delete(id: agg.id)
                        }
                        calendarSelectedVisitId = nil
                    },
                    onUpdate: {
                        Task { store.reload() }
                    },
                    onMapTap: {
                        calendarSelectedVisitId = nil
                        displayMode = .map
                        selectedMapItemId = agg.id
                    }
                )
            }
        }
    }
    
    private var detailSheetBinding: Binding<VisitAggregate?> {
        Binding(
            get: {
                detailSheetItemId.flatMap { id in
                    store.items.first(where: { $0.id == id })
                }
            },
            set: { newValue in
                detailSheetItemId = newValue?.id
            }
        )
    }
    
    @ViewBuilder
    private func editSheet(for agg: VisitAggregate) -> some View {
        NavigationStack {
            EditView(aggregate: agg) {
                Task { store.reload() }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .iPadSheetSize()
        .presentationDragIndicator(.visible)
    }
    
    @ViewBuilder
    private func detailSheet(for agg: VisitAggregate) -> some View {
        NavigationStack {
            VisitDetailScreen(
                data: toDetailData(agg),
                visitId: agg.id,
                onBack: {},
                onEdit: { editingTarget = agg },
                onShare: { /* 共有導線をここに（必要なら）*/ },
                onDelete: {
                    withAnimation {
                        store.delete(id: agg.id)
                    }
                    detailSheetItemId = nil
                },
                onUpdate: {
                    Task { store.reload() }
                },
                onMapTap: {
                    detailSheetItemId = nil
                    selectedMapItemId = agg.id
                }
            )
        }
        .iPadSheetSize()
        .presentationDragIndicator(.visible)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            // ロゴアイコン
            Image("kokokita_irodori_blue")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .opacity(0.3)

            VStack(spacing: 12) {
                Text(L.EmptyState.noRecords)
                    .font(.title2.bold())
                    .foregroundColor(.primary)

                Text(L.EmptyState.noRecordsDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    // MARK: - Map Content
    @ViewBuilder
    private func mapContent() -> some View {
        VisitMapView(
            items: store.items,
            labelMap: labelMap,
            groupMap: groupMap,
            memberMap: memberMap,
            labelColorMap: labelColorMap,
            selectedItemId: $selectedMapItemId,
            sheetHeight: $mapSheetHeight,
            onShowDetail: { id in
                selectedMapItemId = nil
                detailSheetItemId = id
            }
        )
    }

    // MARK: - Calendar Content
    @ViewBuilder
    private func calendarContent() -> some View {
        CalendarContentView(
            visitsByDate: visitsByDateMap,
            aggregatesByDate: aggregatesByDateMap,
            labelMap: labelMap,
            groupMap: groupMap,
            memberMap: memberMap,
            labelColorMap: labelColorMap,
            onTapVisit: { agg in
                calendarSelectedVisitId = agg.id
            },
            onPanelVisibilityChanged: { visible in
                ui.isCalendarVisible = visible
            }
        )
        .task { store.reload() }
        .onReceive(NotificationCenter.default.publisher(for: .visitsChanged)) { _ in
            Task { store.reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .taxonomyChanged)) { _ in
            Task { await store.reloadTaxonomyThenData() }
        }
    }

    private func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return L.Date.today
        } else if calendar.isDateInYesterday(date) {
            return L.Date.yesterday
        } else {
            return AppDateFormatters.listDateHeader.string(from: date)
        }
    }

    private func isWithin24Hours(_ date: Date) -> Bool {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        return timeInterval >= 0 && timeInterval < 24 * 60 * 60 // 24時間 = 86400秒
    }

    private func toDetailData(_ agg: VisitAggregate) -> VisitDetailData {
        let title: String = {
            let t = agg.details.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let t, !t.isEmpty { return t }
            if let f = agg.details.facilityName, !f.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return f }
            return L.Home.noTitle
        }()

        let labels: [String] = agg.details.labelIds.compactMap { labelMap[$0] }
        let group: String?   = agg.details.groupId.flatMap { groupMap[$0] }
        let members: [String] = agg.details.memberIds.compactMap { memberMap[$0] }

        let coord: CLLocationCoordinate2D? = {
            let lat = agg.visit.latitude
            let lon = agg.visit.longitude
            if lat == 0 && lon == 0 { return nil }
            return .init(latitude: lat, longitude: lon)
        }()

        let address = agg.details.resolvedAddress ?? agg.details.facilityAddress

        return VisitDetailData(
            title: title,
            labels: labels,
            group: group,
            members: members,
            timestamp: agg.visit.timestampUTC,
            address: address,
            coordinate: coord,
            memo: agg.details.comment,
            facility: FacilityInfo(
                name: agg.details.facilityName,
                address: agg.details.facilityAddress,
                phone: nil
            ),
            facilityCategory: agg.details.facilityCategory,
            photoPaths: agg.details.photoPaths,
            isManualEntry: agg.visit.isManualEntry
        )
    }

}

// MARK: - 行コンポーネント（別ビューで型推論を軽く）
private struct VisitListRow: View {
    let agg: VisitAggregate
    let labelMap: [UUID: String]
    let groupMap: [UUID: String]
    let memberMap: [UUID: String]
    var labelColorMap: [String: Color] = [:]

    var body: some View {
        let labelNames = agg.details.labelIds.compactMap { labelMap[$0] }
        let groupName  = agg.details.groupId.flatMap { groupMap[$0] }
        let memberNames = agg.details.memberIds.compactMap { memberMap[$0] }
        VisitRow(
            agg: agg,
            nameResolver: { _, _, _ in
                (labels: labelNames, group: groupName, members: memberNames)
            },
            labelColorMap: labelColorMap
        )
    }
}
