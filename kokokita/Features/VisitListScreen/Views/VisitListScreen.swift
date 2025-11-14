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

    // 名前辞書（型を固定して軽くする）
    private var labelMap: [UUID: String] { store.labels.nameMap }
    private var groupMap: [UUID: String] { store.groups.nameMap }
    private var memberMap: [UUID: String] { store.members.nameMap }

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
        if store.items.isEmpty {
            // 空の状態UI
            emptyStateView
        } else {
            actualListView
        }
    }

    // リスト表示本体（型推論を軽くするため分離）
    private var actualListView: some View {
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
            }
        }
        .listStyle(.plain)
        .task { store.reload() }
        .onReceive(NotificationCenter.default.publisher(for: .visitsChanged)) { _ in
            Task { store.reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .taxonomyChanged)) { _ in
            Task { await store.reloadTaxonomyThenData() }
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
        .onChange(of: displayMode) {
            mapSheetHeight = 0
        }
    }
    
    private var contentStack: some View {
        ZStack {
            VStack(spacing: 0) {
                HomeFilterHeader(store: store) {
                    showSearchSheet = true
                }
                .sheet(isPresented: $showSearchSheet) {
                    NavigationStack { SearchFilterSheet(store: store) { showSearchSheet = false } }
                    .presentationDetents([.fraction(0.8)])
                }

                // 表示モードで切り替え
                switch displayMode {
                case .list:
                    listContent()
                case .map:
                    mapContent()
                }
            }

            // 右下にトグルボタン（シート表示時は上にずらす）
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    modeToggleButton
                        .padding(.trailing, 16)
                        .padding(.bottom, mapSheetHeight > 0 ? mapSheetHeight + 16 : 16)
                }
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
        .presentationDetents([.fraction(0.8)])
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
                }
            )
        }
        .presentationDetents([.large])
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
                Text("まだ記録がありません")
                    .font(.title2.bold())
                    .foregroundColor(.primary)

                Text("下の「ココキタ」ボタンをタップして\n今いる場所を記録しましょう")
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

    // MARK: - Mode Toggle Button

    private var modeToggleButton: some View {
        Button {
            withAnimation {
                displayMode = displayMode == .list ? .map : .list
            }
        } label: {
            Image(systemName: displayMode == .list ? "map" : "list.bullet")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.blue, in: Circle())
                .shadow(radius: 4)
        }
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
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日(E)"

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今日"
        } else if calendar.isDateInYesterday(date) {
            return "昨日"
        } else {
            return formatter.string(from: date)
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
