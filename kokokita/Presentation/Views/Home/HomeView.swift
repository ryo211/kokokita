import SwiftUI
import CoreLocation

enum HomeDisplayMode {
    case list
    case map
}

struct HomeView: View {
    @Environment(AppUIState.self) private var ui
    @State private var router = NavigationRouter()
    @State private var vm = HomeViewModel(repo: AppContainer.shared.repo)

    @State private var pendingDeleteId: UUID? = nil
    @State private var showDeleteConfirm = false

    @State private var showSearchSheet = false

    @State private var editingTarget: VisitAggregate? = nil

    @State private var displayMode: HomeDisplayMode = .list
    @State private var selectedMapItemId: UUID? = nil
    @State private var detailSheetItemId: UUID? = nil
    @State private var mapSheetHeight: CGFloat = 0

    // 名前辞書（型を固定して軽くする）
    private var labelMap: [UUID: String] { vm.labels.nameMap }
    private var groupMap: [UUID: String] { vm.groups.nameMap }
    private var memberMap: [UUID: String] { vm.members.nameMap }

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    HomeFilterHeader(vm: vm) {
                        showSearchSheet = true
                    }
                    .sheet(isPresented: $showSearchSheet) {
                        NavigationStack { SearchFilterSheet(vm: vm) { showSearchSheet = false } }
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
        .environment(router)
        .alert(
            item: Binding(
                get: { vm.alert.map { AlertMsg(id: UUID(), text: $0) } },
                set: { _ in vm.alert = nil }
            )
        ) { msg in
            Alert(title: Text(L.Common.error),
                  message: Text(msg.text),
                  dismissButton: .default(Text(L.Common.ok)))
        }
        .navigationTitle(L.Home.title)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: selectedMapItemId) { newValue in
            if newValue == nil {
                mapSheetHeight = 0
            }
        }
        .onChange(of: displayMode) { _ in
            mapSheetHeight = 0
        }
        .sheet(item: $editingTarget) { agg in
            NavigationStack {
                EditView(aggregate: agg) {
                    Task { vm.reload() }
                }
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.fraction(0.8)])   // お好みで
            .presentationDragIndicator(.visible)
        }
        .sheet(item: Binding(
            get: {
                detailSheetItemId.flatMap { id in
                    vm.items.first(where: { $0.id == id })
                }
            },
            set: { newValue in
                detailSheetItemId = newValue?.id
            }
        )) { agg in
            NavigationStack {
                VisitDetailScreen(
                    data: toDetailData(agg),
                    visitId: agg.id,
                    onBack: {},
                    onEdit: { editingTarget = agg },
                    onShare: { /* 共有導線をここに（必要なら）*/ },
                    onDelete: {
                        withAnimation {
                            vm.delete(id: agg.id)
                        }
                        detailSheetItemId = nil
                    },
                    onUpdate: {
                        Task { vm.reload() }
                    }
                )
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - List（分離して軽く）
    @ViewBuilder
    private func listContent() -> some View {
        List {
            ForEach(vm.groupedByDate) { group in
                Section {
                    ForEach(group.items) { agg in
                        NavigationLink {
                            VisitDetailScreen(
                                data: toDetailData(agg),
                                visitId: agg.id,
                                onBack: {},                 // NavigationLink なので未使用
                                onEdit: { editingTarget = agg },
                                onShare: { /* 共有導線をここに（必要なら）*/ },
                                onDelete: {
                                    withAnimation {
                                        vm.delete(id: agg.id)
                                    }
                                },
                                onUpdate: {
                                    Task { vm.reload() }
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
                        // 行全体をほんのり強調（任意）
                        .listRowBackground(
                            (pendingDeleteId == agg.id && showDeleteConfirm)
                            ? Color.red.opacity(0.06)
                            : Color.clear
                        )
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
        .task { vm.reload() }
        .onReceive(NotificationCenter.default.publisher(for: .visitsChanged)) { _ in
            Task { vm.reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .taxonomyChanged)) { _ in
            Task { await vm.reloadTaxonomyThenData() }
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
                        vm.delete(id: id)
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
        HomeMapView(
            items: vm.items,
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
