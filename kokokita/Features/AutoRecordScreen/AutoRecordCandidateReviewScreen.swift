import SwiftUI
import MapKit

/// 自動記録の候補をユーザーがレビューする画面
struct AutoRecordCandidateReviewScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = AutoRecordCandidateStore()
    @State private var editingVisitWrapper: EditingVisitWrapper?
    @State private var dismissingCandidate: VisitCandidate?
    @State private var excludingCandidate: VisitCandidate?
    @State private var excludeLabel: String = ""
    @State private var showDismissAllAlert = false

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.candidates.isEmpty {
                    emptyView
                } else {
                    candidateList
                }
            }
            .navigationTitle(L.AutoRecord.reviewTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L.Common.close) { dismiss() }
                }
                if !store.candidates.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(L.AutoRecord.dismissAll) {
                            showDismissAllAlert = true
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .alert(L.AutoRecord.dismissAllConfirmTitle, isPresented: $showDismissAllAlert) {
                Button(L.AutoRecord.dismissAll, role: .destructive) {
                    try? store.dismissAll()
                }
                Button(L.Common.cancel, role: .cancel) {}
            } message: {
                Text(L.AutoRecord.dismissAllConfirmMessage(store.pendingCount))
            }
            .alert(L.AutoRecord.dismissConfirmTitle, isPresented: Binding<Bool>(
                get: { dismissingCandidate != nil },
                set: { if !$0 { dismissingCandidate = nil } }
            )) {
                Button(L.AutoRecord.dismiss, role: .destructive) {
                    if let c = dismissingCandidate {
                        try? store.dismiss(candidate: c)
                        dismissingCandidate = nil
                    }
                }
                Button(L.Common.cancel, role: .cancel) { dismissingCandidate = nil }
            } message: {
                Text(L.AutoRecord.dismissConfirmMessage)
            }
            .alert(L.AutoRecord.excludeTitle, isPresented: Binding<Bool>(
                get: { excludingCandidate != nil },
                set: { if !$0 { excludingCandidate = nil; excludeLabel = "" } }
            )) {
                TextField(L.AutoRecord.excludeLabelPlaceholder, text: $excludeLabel)
                Button(L.AutoRecord.excludeConfirm, role: .destructive) {
                    if let c = excludingCandidate {
                        try? store.excludeAndDismiss(candidate: c, label: excludeLabel)
                        excludingCandidate = nil
                        excludeLabel = ""
                    }
                }
                Button(L.Common.cancel, role: .cancel) {
                    excludingCandidate = nil
                    excludeLabel = ""
                }
            } message: {
                Text(L.AutoRecord.excludeMessage(Int(AppConfig.autoRecordExclusionRadiusMeters)))
            }
            .sheet(item: $editingVisitWrapper) { wrapper in
                editSheet(visitId: wrapper.visitId)
            }
        }
        .task {
            await store.load()
        }
    }

    // MARK: - 空状態

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            Text(L.AutoRecord.reviewEmpty)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 候補リスト

    private var candidateList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                Text(L.AutoRecord.reviewSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                ForEach(store.candidates) { candidate in
                    CandidateCard(
                        candidate: candidate,
                        onApprove: {
                            if let id = try? store.approve(candidate: candidate) {
                                editingVisitWrapper = EditingVisitWrapper(visitId: id)
                            }
                        },
                        onDismiss: {
                            dismissingCandidate = candidate
                        },
                        onExclude: {
                            excludeLabel = candidate.placeName ?? ""
                            excludingCandidate = candidate
                        }
                    )
                }
            }
            .padding(.vertical)
        }
    }

    // MARK: - 編集シート（承認後）

    @ViewBuilder
    private func editSheet(visitId: UUID) -> some View {
        VisitEditScreenLoader(visitId: visitId) {
            editingVisitWrapper = nil
        }
    }
}

// MARK: - 候補カード

private struct CandidateCard: View {
    let candidate: VisitCandidate
    let onApprove: () -> Void
    let onDismiss: () -> Void
    let onExclude: () -> Void

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = .current
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 地名・ミニマップ
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(candidate.placeName ?? L.AutoRecord.loadingPlace)
                        .font(.headline)
                        .lineLimit(2)
                    Text(dateFormatter.string(from: candidate.arrivalDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                MiniMap(latitude: candidate.latitude, longitude: candidate.longitude)
                    .frame(width: 70, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // メタ情報
            HStack(spacing: 16) {
                if let stay = candidate.stayDuration {
                    Label {
                        Text(L.AutoRecord.stayDurationFormat(Int(stay / 60)))
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Label {
                    Text(L.AutoRecord.accuracyFormat(Int(candidate.horizontalAccuracy)))
                } icon: {
                    Image(systemName: "location.circle")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            // アクションボタン
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Button(role: .destructive) {
                        onDismiss()
                    } label: {
                        Text(L.AutoRecord.dismiss)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        onApprove()
                    } label: {
                        Text(L.AutoRecord.approve)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button(role: .destructive) {
                    onExclude()
                } label: {
                    Label(L.AutoRecord.exclude, systemImage: "location.slash")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

// MARK: - ミニマップ

private struct MiniMap: UIViewRepresentable {
    let latitude: Double
    let longitude: Double

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.isUserInteractionEnabled = false
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )
        map.setRegion(region, animated: false)
        let pin = MKPointAnnotation()
        pin.coordinate = center
        map.addAnnotation(pin)
        return map
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {}
}

// MARK: - 承認後の編集画面ローダー

private struct VisitEditScreenLoader: View {
    let visitId: UUID
    let onClose: () -> Void

    @State private var vm = VisitFormStore()
    @State private var isLoaded = false

    var body: some View {
        Group {
            if isLoaded {
                VisitEditScreen(vm: vm, mode: .edit(id: visitId, onSaved: onClose), onClose: onClose)
            } else {
                ProgressView()
            }
        }
        .task {
            if let agg = try? AppContainer.shared.repo.get(by: visitId) {
                await MainActor.run { vm.loadExisting(agg) }
            }
            isLoaded = true
        }
    }
}

// MARK: - sheet(item:) 用ラッパー

private struct EditingVisitWrapper: Identifiable {
    let id = UUID()
    let visitId: UUID
}
