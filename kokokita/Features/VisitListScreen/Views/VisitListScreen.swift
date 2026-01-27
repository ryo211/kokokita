import SwiftUI
import CoreLocation

enum VisitListDisplayMode {
    case list
    case map
}

struct VisitListScreen: View {
    @Environment(AppUIState.self) private var ui
    @State private var router = NavigationRouter()
    @State private var store = VisitListStore(repo: AppContainer.shared.repo)

    @State private var pendingDeleteId: UUID? = nil
    @State private var showDeleteConfirm = false

    @State private var showSearchSheet = false

    @State private var editingTarget: VisitAggregate? = nil

    @State private var displayMode: VisitListDisplayMode = .list
    @State private var selectedMapItemId: UUID? = nil
    @State private var detailSheetItemId: UUID? = nil
    @State private var mapSheetHeight: CGFloat = 0
    @State private var showModeToggle = true
    @State private var scrollTimer: Timer?

    // 名前辞書（型を固定して軽くする）
    private var labelMap: [UUID: String] { store.labels.nameMap }
    private var groupMap: [UUID: String] { store.groups.nameMap }
    private var memberMap: [UUID: String] { store.members.nameMap }

    // トグルボタンの透明度（地図モードは常に完全表示、リストモードはスクロール状態で変化）
    private var toggleButtonOpacity: Double {
        if displayMode == .map {
            return 1.0
        } else {
            return showModeToggle ? 1.0 : 0.1
        }
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
            .onAppear {
                // 画面表示時（タブ切り替え含む）は常にボタンを完全表示
                scrollTimer?.invalidate()
                scrollTimer = nil
                showModeToggle = true
            }
    }

    // MARK: - List（分離して軽く）
    @ViewBuilder
    private func listContent() -> some View {
        Group {
            if store.items.isEmpty {
                // 空の状態UI
                emptyStateView
            } else {
                actualListView
            }
        }
        .task { store.reload() }
        .onReceive(NotificationCenter.default.publisher(for: .visitsChanged)) { _ in
            Task { store.reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .taxonomyChanged)) { _ in
            Task { await store.reloadTaxonomyThenData() }
        }
    }

    // リスト表示本体（型推論を軽くするため分離）
    private var actualListView: some View {
        List {
            ForEach(store.groupedByDate) { group in
                Section {
                    ForEach(group.items) { agg in
                        listRowView(for: agg)
                            .onAppear {
                                handleScroll()
                            }
                    }
                } header: {
                    Text(formatDateHeader(group.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.plain)
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
            VisitListRow(agg: agg, labelMap: labelMap, groupMap: groupMap, memberMap: memberMap)
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
            (pendingDeleteId == agg.id && showDeleteConfirm)
            ? Color.red.opacity(0.06)
            : Color.clear
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
        }
        .onChange(of: displayMode) { oldValue, newValue in
            mapSheetHeight = 0
            // モード変更時はスクロールタイマーをリセット
            scrollTimer?.invalidate()
            scrollTimer = nil
            // 一覧モードに切り替えた時はボタンを完全表示
            if newValue == .list {
                showModeToggle = true
            }
        }
    }
    
    private var contentStack: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                HomeFilterHeader(store: store) {
                    showSearchSheet = true
                }
                .sheet(isPresented: $showSearchSheet) {
                    NavigationStack { SearchFilterSheet(store: store) { showSearchSheet = false } }
                    .iPadSheetSize()
                }

                // 表示モードで切り替え
                switch displayMode {
                case .list:
                    listContent()
                case .map:
                    mapContent()
                }
            }

            // 右下にトグルボタン（シート表示時は上にずらす、スクロール時はうっすら表示）
            modeToggleButton
                .padding(.trailing, 16)
                .padding(.bottom, mapSheetHeight > 0 ? mapSheetHeight + 24 : 32)
                .opacity(toggleButtonOpacity)
                .animation(.easeInOut(duration: 0.2), value: showModeToggle)
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
                let buttonWidth = (geometry.size.width - 8) / 2
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
                    .offset(x: displayMode == .list ? 4 : buttonWidth + 4)
                    .animation(.interpolatingSpring(stiffness: 150, damping: 18), value: displayMode)

                // ボタンラベル
                HStack(spacing: 0) {
                    // 一覧ボタン
                    Button {
                        displayMode = .list
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet")
                                .font(.caption)
                            Text("一覧")
                                .font(.caption.bold())
                        }
                        .foregroundStyle(displayMode == .list ? Color.accentColor : Color.primary.opacity(0.5))
                        .frame(width: buttonWidth)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // 地図ボタン
                    Button {
                        displayMode = .map
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "map")
                                .font(.caption)
                            Text("地図")
                                .font(.caption.bold())
                        }
                        .foregroundStyle(displayMode == .map ? Color.accentColor : Color.primary.opacity(0.5))
                        .frame(width: buttonWidth)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(4)
            }
        }
        .frame(width: 160, height: 44)
    }

    // MARK: - Map Content
    @ViewBuilder
    private func mapContent() -> some View {
        VisitMapView(
            items: store.items,
            labelMap: labelMap,
            groupMap: groupMap,
            memberMap: memberMap,
            selectedItemId: $selectedMapItemId,
            sheetHeight: $mapSheetHeight,
            onShowDetail: { id in
                selectedMapItemId = nil
                detailSheetItemId = id
            }
        )
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

    // スクロール検知とボタンの表示制御
    private func handleScroll() {
        // スクロール中はボタンをうっすら表示
        withAnimation(.easeOut(duration: 0.15)) {
            showModeToggle = false
        }

        // 既存のタイマーをキャンセル
        scrollTimer?.invalidate()

        // 0.5秒後にボタンを完全表示
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            withAnimation(.easeIn(duration: 0.25)) {
                showModeToggle = true
            }
        }
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
            photoPaths: agg.details.photoPaths
        )
    }

}

// MARK: - 行コンポーネント（別ビューで型推論を軽く）
private struct VisitListRow: View {
    let agg: VisitAggregate
    let labelMap: [UUID: String]
    let groupMap: [UUID: String]
    let memberMap: [UUID: String]

    var body: some View {
        let labelNames = agg.details.labelIds.compactMap { labelMap[$0] }
        let groupName  = agg.details.groupId.flatMap { groupMap[$0] }
        let memberNames = agg.details.memberIds.compactMap { memberMap[$0] }
        VisitRow(agg: agg) { _, _, _ in
            (labels: labelNames, group: groupName, members: memberNames)
        }
    }
}
