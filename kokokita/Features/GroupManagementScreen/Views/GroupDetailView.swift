import SwiftUI
import CoreLocation

struct GroupDetailView: View {
    let group: GroupTag
    var onFinish: (_ updated: GroupTag?, _ deleted: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var store = GroupListStore()
    @State private var name: String
    @State private var showDeleteConfirm = false

    // 関連する訪問記録の表示用
    @State private var relatedVisits: [VisitAggregate] = []
    @State private var labelMap: [UUID: String] = [:]
    @State private var groupMap: [UUID: String] = [:]
    @State private var memberMap: [UUID: String] = [:]
    @State private var editingTarget: VisitAggregate? = nil
    @State private var showVisitDeleteConfirm = false
    @State private var pendingDeleteVisitId: UUID? = nil
    private let repo = AppContainer.shared.repo

    init(group: GroupTag, onFinish: @escaping (_ updated: GroupTag?, _ deleted: Bool) -> Void) {
        self.group = group
        self.onFinish = onFinish
        _name = State(initialValue: group.name)
    }

    var body: some View {
        Form {
            nameSection
            deleteSection
            relatedVisitsSection
        }
        .navigationTitle(L.GroupManagement.detailTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L.Common.save) { save() }
                    .disabled(store.loading || !GroupValidator.isNotEmpty(name))
            }
        }
        .onAppear {
            loadRelatedVisits()
        }
        .sheet(item: $editingTarget) { visit in
            NavigationStack {
                EditView(aggregate: visit) {
                    editingTarget = nil
                    loadRelatedVisits()
                }
            }
        }
        .alert(L.GroupManagement.deleteReallyConfirm, isPresented: $showDeleteConfirm) {
            Button(L.Common.cancel, role: .cancel) {}
            Button(L.Common.delete, role: .destructive) { delete() }
        } message: { Text(L.GroupManagement.deleteIrreversible) }
        .alert(L.Detail.deleteVisitTitle, isPresented: $showVisitDeleteConfirm) {
            Button(L.Common.cancel, role: .cancel) {
                pendingDeleteVisitId = nil
            }
            Button(L.Common.delete, role: .destructive) {
                if let id = pendingDeleteVisitId {
                    deleteVisit(id: id)
                }
            }
        } message: {
            Text(L.Detail.deleteVisitMessage)
        }
        .alert(L.Common.error, isPresented: Binding(get: { store.alert != nil }, set: { _ in store.alert = nil })) {
            Button(L.Common.ok, role: .cancel) {}
        } message: { Text(store.alert ?? "") }
    }

    private func save() {
        if store.update(id: group.id, name: name) {
            onFinish(GroupTag(id: group.id, name: name), false)
            dismiss()
        }
    }

    private func delete() {
        if store.delete(id: group.id) {
            onFinish(nil, true)
            dismiss()
        }
    }

    // MARK: - Sections

    private var nameSection: some View {
        Section {
            TextField(L.GroupManagement.namePlaceholder, text: $name)
                .submitLabel(.done)
                .onSubmit {
                    if GroupValidator.isNotEmpty(name) {
                        save()
                    }
                }
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label(L.GroupManagement.deleteConfirm, systemImage: "trash")
            }
        } footer: {
            Text(L.GroupManagement.deleteFooter)
        }
    }

    @ViewBuilder
    private var relatedVisitsSection: some View {
        if !relatedVisits.isEmpty {
            Section {
                ForEach(relatedVisits, id: \.id) { visit in
                    visitRowView(for: visit)
                }
            } header: {
                Text("\(L.GroupManagement.relatedVisitsHeader) (\(relatedVisits.count)\(L.Home.itemsCount))")
            }
        }
    }

    // MARK: - Helper Methods

    private func deleteVisit(id: UUID) {
        do {
            try repo.delete(id: id)
            pendingDeleteVisitId = nil
            loadRelatedVisits()
        } catch {
            Logger.error("Failed to delete visit: \(error.localizedDescription)")
        }
    }

    @ViewBuilder
    private func visitRowView(for visit: VisitAggregate) -> some View {
        NavigationLink {
            VisitDetailScreen(
                data: toDetailData(visit),
                visitId: visit.id,
                onBack: {},
                onEdit: { editingTarget = visit },
                onShare: {},
                onDelete: {
                    pendingDeleteVisitId = visit.id
                    showVisitDeleteConfirm = true
                },
                onUpdate: {
                    loadRelatedVisits()
                },
                onMapTap: nil
            )
        } label: {
            VisitRow(agg: visit, nameResolver: nameResolver)
        }
    }

    private func nameResolver(_ labelIds: [UUID], _ groupId: UUID?, _ memberIds: [UUID]) -> (labels: [String], group: String?, members: [String]) {
        let labels = labelIds.compactMap { labelMap[$0] }
        let group = groupId.flatMap { groupMap[$0] }
        let members = memberIds.compactMap { memberMap[$0] }
        return (labels, group, members)
    }

    private func loadRelatedVisits() {
        do {
            // タクソノミーデータを取得
            let labels = try repo.allLabels()
            let groups = try repo.allGroups()
            let members = try repo.allMembers()

            labelMap = Dictionary(uniqueKeysWithValues: labels.map { ($0.id, $0.name) })
            groupMap = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0.name) })
            memberMap = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0.name) })

            // このグループを使用している訪問記録を取得
            let visits = try repo.fetchAll(
                filterLabel: nil,
                filterGroup: group.id,
                filterMember: nil,
                titleQuery: nil,
                dateFrom: nil,
                dateToExclusive: nil
            )

            // 日付順、降順でソート
            relatedVisits = visits.sorted { $0.visit.timestampUTC > $1.visit.timestampUTC }
        } catch {
            Logger.error("Failed to load related visits: \(error.localizedDescription)")
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
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }()

        let facility: FacilityInfo? = {
            guard let name = agg.details.facilityName else { return nil }
            return FacilityInfo(
                name: name,
                address: agg.details.facilityAddress,
                phone: nil
            )
        }()

        return VisitDetailData(
            title: title,
            labels: labels,
            group: group,
            members: members,
            timestamp: agg.visit.timestampUTC,
            address: agg.details.resolvedAddress,
            coordinate: coord,
            memo: agg.details.comment,
            facility: facility,
            facilityCategory: agg.details.facilityCategory,
            photoPaths: agg.details.photoPaths
        )
    }
}
