import SwiftUI
import MapKit
import CoreLocation

// MARK: - 詳細画面
struct VisitDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    let data: VisitDetailData
    let visitId: UUID  // 編集用にIDを追加
    let onBack: () -> Void
    let onEdit: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void
    let onUpdate: () -> Void  // 更新時のコールバック
    let onMapTap: (() -> Void)?  // 地図タップ時のコールバック

    // 地図カメラ
    @State private var camera: MapCameraPosition

//    @State private var shareImage: UIImage? = nil
//    @State private var showShareSheet = false
    @State private var sharePayload: SharePayload? = nil
    @State private var showDeleteAlert = false

    // チップ編集用の状態
    @State private var labelPickerShown = false
    @State private var groupPickerShown = false
    @State private var memberPickerShown = false

    @State private var labelCreateShown = false
    @State private var groupCreateShown = false
    @State private var memberCreateShown = false

    @State private var newLabelName = ""
    @State private var newGroupName = ""
    @State private var newMemberName = ""

    @State private var labelOptions: [LabelTag] = []
    @State private var groupOptions: [GroupTag] = []
    @State private var memberOptions: [MemberTag] = []

    @State private var selectedLabelIds: Set<UUID> = []
    @State private var selectedGroupId: UUID? = nil
    @State private var selectedMemberIds: Set<UUID> = []
    // SNSカードの論理サイズ（表示用は1/3で描画、保存はscale=3で 1080x1350）
    private let logicalSize = CGSize(width: AppConfig.shareImageLogicalWidth,
                                      height: AppConfig.shareImageLogicalHeight)
    
    init(data: VisitDetailData,
         visitId: UUID,
         onBack: @escaping () -> Void = {},
         onEdit: @escaping () -> Void = {},
         onShare: @escaping () -> Void = {},
         onDelete: @escaping () -> Void = {},
         onUpdate: @escaping () -> Void = {},
         onMapTap: (() -> Void)? = nil) {
        self.data = data
        self.visitId = visitId
        self.onBack = onBack
        self.onEdit = onEdit
        self.onShare = onShare
        self.onDelete = onDelete
        self.onUpdate = onUpdate
        self.onMapTap = onMapTap

        if let c = data.coordinate {
            let region = MKCoordinateRegion(center: c,
                                            latitudinalMeters: AppConfig.mapDisplayRadius * 2,
                                            longitudinalMeters: AppConfig.mapDisplayRadius * 2)
            _camera = State(initialValue: .region(region))
        } else {
            _camera = State(initialValue: .automatic) // 位置なし
        }
    }

    var body: some View {
        ZStack {
            // 背景：淡いグラデーション
            LinearGradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VisitDetailContent(
                    data: data,
                    mapSnapshot: nil,
                    isSharing: false,
                    onLabelTap: { labelPickerShown = true },
                    onGroupTap: { groupPickerShown = true },
                    onMemberTap: { memberPickerShown = true },
                    onMapTap: {
                        dismiss()
                        onMapTap?()
                    }
                )
            }

        }
        // ▼ 標準の戻るボタンを活かしつつ、右側に「編集」を出す
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    onEdit()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.pencil")
                        Text(L.Common.edit)
                    }
                    .font(.subheadline.weight(.semibold))
                }

                Button {
                    Task { await makeAndShare() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text(L.Common.share)
                    }
                    .font(.subheadline.weight(.semibold))
                }

                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel(L.Common.delete)
            }
        }

        .sheet(item: $sharePayload) { payload in
            ActivityView(items: [payload.text, payload.image])
        }
        .alert(L.Detail.deleteConfirmTitle, isPresented: $showDeleteAlert) {
            Button(L.Common.delete, role: .destructive) {
                onDelete()
                dismiss()
            }
            Button(L.Common.cancel, role: .cancel) { }
        } message: {
            Text(L.Detail.deleteConfirmMessage)
        }
        // ラベルピッカー
        .sheet(isPresented: $labelPickerShown) {
            NavigationStack {
                LabelPickerSheet(
                    selectedIds: $selectedLabelIds,
                    labelOptions: $labelOptions,
                    isPresented: $labelPickerShown,
                    showCreateSheet: $labelCreateShown,
                    showDoneButton: false
                )
                .navigationTitle(L.LabelManagement.selectTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L.Common.close) { labelPickerShown = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L.Common.save) {
                            saveLabels()
                            labelPickerShown = false
                        }
                    }
                }
            }
            .sheet(isPresented: $labelCreateShown) {
                LabelCreateSheet(
                    newLabelName: $newLabelName,
                    isPresented: $labelCreateShown,
                    onCreate: createLabelAndSelect
                )
            }
        }
        // グループピッカー
        .sheet(isPresented: $groupPickerShown) {
            NavigationStack {
                GroupPickerSheet(
                    selectedId: $selectedGroupId,
                    groupOptions: $groupOptions,
                    isPresented: $groupPickerShown,
                    showCreateSheet: $groupCreateShown,
                    showClearButton: true,
                    showDoneButton: false
                )
                .navigationTitle(L.GroupManagement.selectTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L.Common.close) { groupPickerShown = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L.Common.save) {
                            saveGroup()
                            groupPickerShown = false
                        }
                    }
                }
            }
            .sheet(isPresented: $groupCreateShown) {
                GroupCreateSheet(
                    newGroupName: $newGroupName,
                    isPresented: $groupCreateShown,
                    onCreate: createGroupAndSelect
                )
            }
        }
        // メンバーピッカー
        .sheet(isPresented: $memberPickerShown) {
            NavigationStack {
                MemberPickerSheet(
                    selectedIds: $selectedMemberIds,
                    memberOptions: $memberOptions,
                    isPresented: $memberPickerShown,
                    showCreateSheet: $memberCreateShown,
                    showDoneButton: false
                )
                .navigationTitle(L.MemberManagement.selectTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L.Common.close) { memberPickerShown = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L.Common.save) {
                            saveMembers()
                            memberPickerShown = false
                        }
                    }
                }
            }
            .sheet(isPresented: $memberCreateShown) {
                MemberCreateSheet(
                    newMemberName: $newMemberName,
                    isPresented: $memberCreateShown,
                    onCreate: createMemberAndSelect
                )
            }
        }
        .task {
            await loadTaxonomyData()
        }
    }

    // MARK: - データロード
    private func loadTaxonomyData() async {
        labelOptions = ((try? AppContainer.shared.repo.allLabels()) ?? []).sortedByName
        groupOptions = ((try? AppContainer.shared.repo.allGroups()) ?? []).sortedByName
        memberOptions = ((try? AppContainer.shared.repo.allMembers()) ?? []).sortedByName

        // 現在の値を取得
        if let agg = try? AppContainer.shared.repo.get(by: visitId) {
            selectedLabelIds = Set(agg.details.labelIds)
            selectedGroupId = agg.details.groupId
            selectedMemberIds = Set(agg.details.memberIds)
        }
    }

    // MARK: - 新規作成
    private func createLabelAndSelect() {
        let name = newLabelName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        if let exist = labelOptions.first(where: { $0.name == name }) {
            selectedLabelIds.insert(exist.id)
        } else {
            do {
                let id = try AppContainer.shared.repo.createLabel(name: name)
                let tag = LabelTag(id: id, name: name)
                labelOptions.append(tag)
                selectedLabelIds.insert(id)
                NotificationCenter.default.post(name: .taxonomyChanged, object: nil)
            } catch {
                Logger.error("Failed to create label", error: error)
            }
        }
        newLabelName = ""
        labelCreateShown = false
    }

    private func createGroupAndSelect() {
        let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        if let exist = groupOptions.first(where: { $0.name == name }) {
            selectedGroupId = exist.id
        } else {
            do {
                let id = try AppContainer.shared.repo.createGroup(name: name)
                let tag = GroupTag(id: id, name: name)
                groupOptions.append(tag)
                selectedGroupId = id
                NotificationCenter.default.post(name: .taxonomyChanged, object: nil)
            } catch {
                Logger.error("Failed to create group", error: error)
            }
        }
        newGroupName = ""
        groupCreateShown = false
    }

    private func createMemberAndSelect() {
        let name = newMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        if let exist = memberOptions.first(where: { $0.name == name }) {
            selectedMemberIds.insert(exist.id)
        } else {
            do {
                let id = try AppContainer.shared.repo.createMember(name: name)
                let tag = MemberTag(id: id, name: name)
                memberOptions.append(tag)
                selectedMemberIds.insert(id)
                NotificationCenter.default.post(name: .taxonomyChanged, object: nil)
            } catch {
                Logger.error("Failed to create member", error: error)
            }
        }
        newMemberName = ""
        memberCreateShown = false
    }

    // MARK: - 保存処理
    private func saveLabels() {
        do {
            try AppContainer.shared.repo.updateDetails(id: visitId) { details in
                details.labelIds = Array(selectedLabelIds)
            }
            onUpdate()
        } catch {
            Logger.error("Failed to update labels", error: error)
        }
    }

    private func saveGroup() {
        do {
            try AppContainer.shared.repo.updateDetails(id: visitId) { details in
                details.groupId = selectedGroupId
            }
            onUpdate()
        } catch {
            Logger.error("Failed to update group", error: error)
        }
    }

    private func saveMembers() {
        do {
            try AppContainer.shared.repo.updateDetails(id: visitId) { details in
                details.memberIds = Array(selectedMemberIds)
            }
            onUpdate()
        } catch {
            Logger.error("Failed to update members", error: error)
        }
    }
    
    private func shareText() -> String {
        var lines: [String] = []
        lines.append("【\(L.App.name)】")
        lines.append(data.title.ifBlank(L.Home.noTitle))
        lines.append(data.timestamp.kokokitaVisitString)
//        if let addr = data.address?.trimmingCharacters(in: .whitespacesAndNewlines), !addr.isEmpty {
//            lines.append(addr)
//        }
        return lines.joined(separator: "\n")
    }

    private func shareMapSize() -> CGSize {
        // 共有カード内の地図高さと同じにする（余白込みで多少小さめでもOK）
        CGSize(width: logicalSize.width, height: 300)
    }

    private func makeAndShare() async {
        // 1) 地図スナップショット（オフスクリーンでも確実に出る）
        var mapImage: UIImage? = nil
        if let c = data.coordinate {
            mapImage = await MapSnapshotService.makeSnapshot(
                center: c,
                size: CGSize(width: AppConfig.shareImageLogicalWidth, height: UIConstants.Size.shareMapHeight),
                spanMeters: AppConfig.mapDisplayRadius,
                showCoordinateBadge: true,   // ← バッジを載せる
                decimals: AppConfig.coordinateDecimals,
                badgeInset: UIConstants.Spacing.medium
            )
        }

        // 2) 同じ中身を共有用フラグでレンダリング
        let img: UIImage? = await MainActor.run {
            let content = VStack(spacing: 0) {
                VisitDetailContent(data: data, mapSnapshot: mapImage, isSharing: true)
                    .padding(.all, UIConstants.Spacing.xxLarge)
            }
            return ShareImageRenderer.renderWidth(content, width: AppConfig.shareImageLogicalWidth, scale: AppConfig.shareImageScale)
        }

        // 3) シート表示（前回の SharePayload 方式）
        if let img {
            await MainActor.run {
                self.sharePayload = SharePayload(image: img, text: shareText())
            }
        }
    }


    
}

// MARK: - データ受け渡し用の軽量モデル（UI草案用）
struct VisitDetailData {
    var title: String
    var labels: [String]
    var group: String?
    var members: [String]
    var timestamp: Date
    var address: String?
    var coordinate: CLLocationCoordinate2D?
    var memo: String?
    var facility: FacilityInfo?
    var facilityCategory: String?
    var photoPaths: [String]
}


struct SharePayload: Identifiable {
    let id = UUID()
    let image: UIImage
    let text: String
}
