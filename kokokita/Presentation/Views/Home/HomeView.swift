import SwiftUI
import CoreLocation

struct HomeView: View {
    @EnvironmentObject private var ui: AppUIState
    @StateObject private var router = NavigationRouter()
    @StateObject private var vm = HomeViewModel(repo: AppContainer.shared.repo)

    @State private var pendingDeleteId: UUID? = nil
    @State private var showDeleteConfirm = false
    
    @State private var showSearchSheet = false
    
    @State private var editingTarget: VisitAggregate? = nil
    
    // 名前辞書（型を固定して軽くする）
    private var labelMap: [UUID: String] { vm.labels.nameMap }
    private var groupMap: [UUID: String] { vm.groups.nameMap }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HomeFilterHeader(vm: vm) {
                    showSearchSheet = true
                }
                .sheet(isPresented: $showSearchSheet) {
                    NavigationStack { SearchFilterSheet(vm: vm) { showSearchSheet = false } }
                    .presentationDetents([.fraction(0.8)])
                }
                listContent()
            }
        }
        .environmentObject(router)
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
    }

    // MARK: - List（分離して軽く）
    @ViewBuilder
    private func listContent() -> some View {
        List {
            ForEach(vm.items) { agg in
                NavigationLink {
                    VisitDetailScreen(
                        data: toDetailData(agg),
                        onBack: {},                 // NavigationLink なので未使用
                        onEdit: { editingTarget = agg },
                        onShare: { /* 共有導線をここに（必要なら）*/ },
                        onDelete: {
                            withAnimation {
                                vm.delete(id: agg.id)
                            }
                        }
                    )
                } label: {
                    VisitListRow(agg: agg, labelMap: labelMap, groupMap: groupMap)
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
    
    private func toDetailData(_ agg: VisitAggregate) -> VisitDetailData {
        let title: String = {
            let t = agg.details.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let t, !t.isEmpty { return t }
            if let f = agg.details.facilityName, !f.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return f }
            return L.Home.noTitle
        }()

        let labels: [String] = agg.details.labelIds.compactMap { labelMap[$0] }
        let group: String?   = agg.details.groupId.flatMap { groupMap[$0] }

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
            timestamp: agg.visit.timestampUTC,
            address: address,
            coordinate: coord,
            memo: agg.details.comment,
            facility: FacilityInfo(
                name: agg.details.facilityName,
                address: agg.details.facilityAddress,
                phone: nil
            ),
            photoPaths: agg.details.photoPaths
        )
    }

}

// MARK: - 行コンポーネント（別ビューで型推論を軽く）
private struct VisitListRow: View {
    let agg: VisitAggregate
    let labelMap: [UUID: String]
    let groupMap: [UUID: String]

    var body: some View {
        let labelNames = agg.details.labelIds.compactMap { labelMap[$0] }
        let groupName  = agg.details.groupId.flatMap { groupMap[$0] }
        VisitRow(agg: agg) { _, _ in
            (labels: labelNames, group: groupName)
        }
    }
}
