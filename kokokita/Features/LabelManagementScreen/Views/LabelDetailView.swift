import SwiftUI
import CoreLocation

private struct VisitSelection: Identifiable, Hashable {
    let id: UUID
}

struct LabelDetailView: View {
    let label: LabelTag
    var onFinish: (_ updated: LabelTag?, _ deleted: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppUIState.self) private var ui
    @State private var store = LabelListStore()
    @State private var name: String
    @State private var editingName: String = ""
    @State private var editingColorId: String?
    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false
    @State private var currentColorId: String?

    // 関連する訪問記録の表示用
    @State private var relatedVisits: [VisitAggregate] = []
    @State private var labelMap: [UUID: String] = [:]
    @State private var groupMap: [UUID: String] = [:]
    @State private var memberMap: [UUID: String] = [:]
    @State private var visitLabelColorMap: [String: Color] = [:]
    @State private var editingTarget: VisitAggregate? = nil
    @State private var showVisitDeleteConfirm = false
    @State private var pendingDeleteVisitId: UUID? = nil
    @State private var selectedVisit: VisitSelection? = nil
    @State private var focusedVisitId: UUID? = nil
    private let repo = AppContainer.shared.repo

    init(label: LabelTag, onFinish: @escaping (_ updated: LabelTag?, _ deleted: Bool) -> Void) {
        self.label = label
        self.onFinish = onFinish
        _name = State(initialValue: label.name)
        _currentColorId = State(initialValue: label.colorId)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 固定部分：名前表示と編集ボタン、ヘッダー
            VStack(spacing: 0) {
                nameSection
                    .padding(.horizontal)
                    .padding(.vertical, 16)

                if !relatedVisits.isEmpty {
                    TaxonomyDetailMapView(
                        visits: relatedVisits,
                        labelMap: labelMap,
                        labelColorMap: visitLabelColorMap,
                        focusedVisitId: $focusedVisitId
                    )
                    .containerRelativeFrame(.vertical, count: 10, span: 3, spacing: 0)
                }

                if !relatedVisits.isEmpty {
                    HStack {
                        Text("\(L.LabelManagement.relatedVisitsHeader) (\(relatedVisits.count)\(L.Home.itemsCount))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                }

                Divider()
            }
            .background(Color(.systemBackground))

            // スクロール可能な部分：関連する記録のリストのみ
            if !relatedVisits.isEmpty {
                ScrollViewReader { proxy in
                    List {
                        ForEach(relatedVisits, id: \.id) { visit in
                            visitRowView(for: visit)
                                .id(visit.id)
                        }
                    }
                    .listStyle(.plain)
                    .navigationDestination(item: $selectedVisit) { selection in
                        if let visit = relatedVisits.first(where: { $0.id == selection.id }) {
                            VisitDetailScreen(
                                data: toDetailData(visit),
                                visitId: selection.id,
                                onBack: {},
                                onEdit: { editingTarget = visit },
                                onShare: {},
                                onDelete: {
                                    pendingDeleteVisitId = selection.id
                                    showVisitDeleteConfirm = true
                                },
                                onUpdate: {
                                    loadRelatedVisits()
                                },
                                onMapTap: { ui.mapFocusVisitId = selection.id }
                            )
                        }
                    }
                    .onChange(of: focusedVisitId) { _, newId in
                        if let newId {
                            withAnimation { proxy.scrollTo(newId, anchor: .center) }
                        }
                    }
                }
            } else {
                Spacer()
            }
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            NavigationStack {
                Form {
                    Section {
                        TextField(L.LabelManagement.namePlaceholder, text: $editingName)
                            .submitLabel(.done)
                            .onSubmit {
                                if LabelValidator.isNotEmpty(editingName) {
                                    saveEdit()
                                }
                            }
                    } header: {
                        Text(L.LabelManagement.namePlaceholder)
                    }
                    Section {
                        LabelColorPicker(selectedColorId: editingColorId) { newColorId in
                            editingColorId = newColorId
                        }
                    } header: {
                        Text(L.LabelColor.sectionTitle)
                    }
                }
                .navigationTitle(L.Common.edit)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(L.Common.cancel) {
                            showEditSheet = false
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(L.Common.save) {
                            saveEdit()
                        }
                        .disabled(store.loading || !LabelValidator.isNotEmpty(editingName))
                    }
                }
            }
            .presentationDetents([.height(320)])
        }
        .onChange(of: showEditSheet) { _, isShowing in
            if isShowing {
                editingName = name
                editingColorId = currentColorId
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
        .alert(L.LabelManagement.deleteReallyConfirm, isPresented: $showDeleteConfirm) {
            Button(L.Common.cancel, role: .cancel) {}
            Button(L.Common.delete, role: .destructive) { delete() }
        } message: { Text(L.LabelManagement.deleteIrreversible) }
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
        if store.update(id: label.id, name: name) {
            onFinish(LabelTag(id: label.id, name: name, colorId: currentColorId), false)
            dismiss()
        }
    }

    private func saveEdit() {
        guard store.update(id: label.id, name: editingName) else { return }
        guard store.updateColor(id: label.id, colorId: editingColorId) else { return }
        name = editingName
        currentColorId = editingColorId
        showEditSheet = false
    }

    private func delete() {
        if store.delete(id: label.id) {
            onFinish(nil, true)
            dismiss()
        }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L.LabelManagement.namePlaceholder)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .bottom) {
                HStack(spacing: 8) {
                    Image(systemName: "tag")
                        .imageScale(.medium)
                        .font(.title3)
                        .foregroundStyle(LabelColorId.from(currentColorId)?.color ?? ChipKind.defaultTint)
                    Text(name)
                        .font(.title3.bold())
                }
                Spacer()
                Button {
                    showEditSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text(L.Common.edit)
                    }
                    .font(.subheadline)
                }
            }
            .padding(.bottom, 4)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.primary.opacity(0.3))
                    .frame(height: 1)
            }
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
                Text("\(L.LabelManagement.relatedVisitsHeader) (\(relatedVisits.count)\(L.Home.itemsCount))")
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
        let isFocused = focusedVisitId == visit.id
        HStack(spacing: 0) {
            VisitRow(agg: visit, nameResolver: nameResolver, compact: true, labelColorMap: visitLabelColorMap)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedVisitId = (focusedVisitId == visit.id ? nil : visit.id)
                }
            Button {
                selectedVisit = VisitSelection(id: visit.id)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .listRowBackground(isFocused ? Color.blue.opacity(0.1) : nil)
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
            visitLabelColorMap = labels.colorMap

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
            photoPaths: agg.details.photoPaths,
            isManualEntry: agg.visit.isManualEntry
        )
    }
}
