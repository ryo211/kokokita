import SwiftUI
import CoreLocation

// 記録機能のオーバーレイ（ローディング・シート・アラート）をまとめて付与するViewModifier
struct RecordingOverlay: ViewModifier {
    @Bindable var recording: RecordingController

    func body(content: Content) -> some View {
        content
            // ローディングオーバーレイ
            .overlay {
                if recording.showLocationLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        VStack(spacing: 24) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                            VStack(spacing: 8) {
                                Text(L.Location.acquiringLocation)
                                    .font(.headline)
                                Text(L.Location.pleaseWait)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(32)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color(.systemBackground))
                                .shadow(radius: 20)
                        )
                        .padding(40)
                    }
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: recording.showLocationLoading)
                }
            }
            // 確認シート（記録直後）
            .sheet(isPresented: Binding(
                get: { recording.confirmationSheetVisitId != nil },
                set: { if !$0 { recording.confirmationSheetVisitId = nil } }
            ), onDismiss: {
                AppReviewService.shared.onRecordSheetDismissed()
            }) {
                if let visitId = recording.confirmationSheetVisitId {
                    PostKokokitaConfirmationSheet(
                        visitId: visitId,
                        onEnterInfo: { id in
                            recording.confirmationSheetVisitId = nil
                            recording.editVisitId = id
                        },
                        onViewDetail: { id in
                            recording.confirmationSheetVisitId = nil
                            recording.detailVisitId = id
                        },
                        onDelete: { id in
                            recording.deleteVisit(id: id)
                        }
                    )
                    .iPadSheetSize()
                }
            }
            // チェックイン結果シート
            .sheet(isPresented: Binding(
                get: { !recording.pendingCheckInResults.isEmpty },
                set: { if !$0 {
                    recording.pendingCheckInResults = []
                    if let id = recording.pendingConfirmationId {
                        recording.confirmationSheetVisitId = id
                        recording.pendingConfirmationId = nil
                    }
                }}
            )) {
                CheckInResultSheet(results: recording.pendingCheckInResults) {
                    recording.pendingCheckInResults = []
                }
            }
            // 編集シート
            .sheet(isPresented: Binding(
                get: { recording.editVisitId != nil },
                set: { if !$0 { recording.editVisitId = nil } }
            ), onDismiss: {
                NotificationCenter.default.post(name: .visitsChanged, object: nil)
            }) {
                if let visitId = recording.editVisitId {
                    RecordingEditVisitSheet(visitId: visitId)
                        .iPadSheetSize()
                        .ignoresSafeArea(.keyboard, edges: .bottom)
                }
            }
            // 詳細シート
            .sheet(isPresented: Binding(
                get: { recording.detailVisitId != nil },
                set: { if !$0 { recording.detailVisitId = nil } }
            )) {
                if let visitId = recording.detailVisitId {
                    RecordingDetailVisitSheet(visitId: visitId)
                        .iPadSheetSize()
                }
            }
            // 後付け記録シート
            .sheet(isPresented: $recording.showManualEntrySheet, onDismiss: {
                NotificationCenter.default.post(name: .visitsChanged, object: nil)
                AppReviewService.shared.onRecordSheetDismissed()
            }) {
                ManualEntryScreen()
                    .iPadSheetSize()
            }
            // 位置情報権限アラート
            .alert(L.Location.permissionRequired, isPresented: $recording.showLocationPermissionAlert) {
                Button(L.Location.openSettings) { recording.openSettings() }
                Button(L.Common.cancel, role: .cancel) {}
            } message: {
                Text(L.Location.permissionMessage)
            }
            // 位置情報取得エラーアラート
            .alert(L.Location.acquisitionFailed, isPresented: Binding(
                get: { recording.locationErrorMessage != nil },
                set: { if !$0 { recording.locationErrorMessage = nil } }
            )) {
                Button(L.Common.ok, role: .cancel) {
                    recording.locationErrorMessage = nil
                }
            } message: {
                Text(recording.locationErrorMessage ?? "")
            }
    }
}

extension View {
    func recordingOverlay(_ recording: RecordingController) -> some View {
        modifier(RecordingOverlay(recording: recording))
    }
}

// MARK: - 編集シート

struct RecordingEditVisitSheet: View {
    let visitId: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var visit: VisitAggregate?

    var body: some View {
        Group {
            if let visit = visit {
                EditView(aggregate: visit) {
                    dismiss()
                }
            } else {
                ProgressView()
                    .task { await loadVisit() }
            }
        }
    }

    @MainActor
    private func loadVisit() async {
        do {
            visit = try AppContainer.shared.repo.get(by: visitId)
        } catch {
            Logger.error("Failed to load visit for editing", error: error)
        }
    }
}

// MARK: - 詳細シート

struct RecordingDetailVisitSheet: View {
    let visitId: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(AppUIState.self) private var ui
    @State private var visit: VisitAggregate?
    @State private var labelMap: [UUID: String] = [:]
    @State private var groupMap: [UUID: String] = [:]
    @State private var memberMap: [UUID: String] = [:]

    var body: some View {
        Group {
            if let visit = visit {
                NavigationStack {
                    VisitDetailScreen(
                        data: toDetailData(visit),
                        visitId: visitId,
                        onBack: {},
                        onEdit: {},
                        onShare: {},
                        onDelete: {
                            deleteVisit()
                            dismiss()
                        },
                        onUpdate: {},
                        onMapTap: {
                            dismiss()
                            ui.mapFocusVisitId = visitId
                        }
                    )
                }
            } else {
                ProgressView()
                    .task { await loadVisit() }
            }
        }
    }

    @MainActor
    private func loadVisit() async {
        do {
            visit = try AppContainer.shared.repo.get(by: visitId)
            let labels = try AppContainer.shared.repo.allLabels()
            let groups = try AppContainer.shared.repo.allGroups()
            let members = try AppContainer.shared.repo.allMembers()
            labelMap = Dictionary(uniqueKeysWithValues: labels.map { ($0.id, $0.name) })
            groupMap = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0.name) })
            memberMap = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0.name) })
        } catch {
            Logger.error("Failed to load visit for detail", error: error)
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
        let group: String? = agg.details.groupId.flatMap { groupMap[$0] }
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

    private func deleteVisit() {
        do {
            try AppContainer.shared.repo.delete(id: visitId)
            NotificationCenter.default.post(name: .visitsChanged, object: nil)
        } catch {
            Logger.error("Failed to delete visit from detail sheet", error: error)
        }
    }
}
