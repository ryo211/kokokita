import SwiftUI
import CoreLocation

struct LabelDetailView: View {
    let label: LabelTag
    var onFinish: (_ updated: LabelTag?, _ deleted: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var store = LabelListStore()
    @State private var name: String
    @State private var showDeleteConfirm = false

    // 関連する訪問記録の表示用
    @State private var relatedVisits: [VisitAggregate] = []
    @State private var labelMap: [UUID: String] = [:]
    @State private var groupMap: [UUID: String] = [:]
    @State private var memberMap: [UUID: String] = [:]
    private let repo = AppContainer.shared.repo

    init(label: LabelTag, onFinish: @escaping (_ updated: LabelTag?, _ deleted: Bool) -> Void) {
        self.label = label
        self.onFinish = onFinish
        _name = State(initialValue: label.name)
    }

    var body: some View {
        Form {
            Section { TextField(L.LabelManagement.namePlaceholder, text: $name)
                .submitLabel(.done)
                .onSubmit {
                    if LabelValidator.isNotEmpty(name) {
                        save()
                    }
                }
            }
            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: { Label(L.LabelManagement.deleteConfirm, systemImage: "trash") }
            } footer: { Text(L.LabelManagement.deleteFooter) }

            // 関連する訪問記録セクション
            if !relatedVisits.isEmpty {
                Section {
                    ForEach(relatedVisits, id: \.id) { visit in
                        NavigationLink {
                            VisitDetailScreen(
                                data: toDetailData(visit),
                                visitId: visit.id,
                                onBack: {},
                                onEdit: {},
                                onShare: {},
                                onDelete: {},
                                onUpdate: {},
                                onMapTap: nil
                            )
                        } label: {
                            VisitRow(
                                agg: visit,
                                nameResolver: { labelIds, groupId, memberIds in
                                    let labels = labelIds.compactMap { labelMap[$0] }
                                    let group = groupId.flatMap { groupMap[$0] }
                                    let members = memberIds.compactMap { memberMap[$0] }
                                    return (labels, group, members)
                                }
                            )
                        }
                    }
                } header: {
                    Text("このラベルを使用している記録")
                }
            }
        }
        .navigationTitle(L.LabelManagement.detailTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L.Common.save) { save() }
                    .disabled(store.loading || !LabelValidator.isNotEmpty(name))
            }
        }
        .onAppear {
            loadRelatedVisits()
        }
        .alert(L.LabelManagement.deleteReallyConfirm, isPresented: $showDeleteConfirm) {
            Button(L.Common.cancel, role: .cancel) {}
            Button(L.Common.delete, role: .destructive) { delete() }
        } message: { Text(L.LabelManagement.deleteIrreversible) }
        .alert(L.Common.error, isPresented: Binding(get: { store.alert != nil }, set: { _ in store.alert = nil })) {
            Button(L.Common.ok, role: .cancel) {}
        } message: { Text(store.alert ?? "") }
    }

    private func save() {
        if store.update(id: label.id, name: name) {
            onFinish(LabelTag(id: label.id, name: name), false)
            dismiss()
        }
    }

    private func delete() {
        if store.delete(id: label.id) {
            onFinish(nil, true)
            dismiss()
        }
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

            // このラベルを使用している訪問記録を取得
            let visits = try repo.fetchAll(
                filterLabel: label.id,
                filterGroup: nil,
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
            return "タイトルなし"
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
