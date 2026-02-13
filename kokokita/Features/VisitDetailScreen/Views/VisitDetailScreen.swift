import SwiftUI
import MapKit
import CoreLocation

// MARK: - 詳細画面
struct VisitDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppUIState.self) private var appUIState
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

    // タクソノミー詳細画面への遷移用
    @State private var selectedLabel: LabelTag? = nil
    @State private var selectedGroup: GroupTag? = nil
    @State private var selectedMember: MemberTag? = nil

    @State private var labelOptions: [LabelTag] = []
    @State private var groupOptions: [GroupTag] = []
    @State private var memberOptions: [MemberTag] = []

    // 写真全画面表示用
    @State private var photoFullScreenIndex: Int? = nil
    @State private var photoDragOffset: CGFloat = 0

    // 近くの過去記録
    @State private var nearbyVisits: [VisitAggregate] = []
    @State private var nearbyVisitsData: [VisitDetailData] = []

    // 同じグループの記録
    @State private var sameGroupVisits: [VisitAggregate] = []
    @State private var sameGroupVisitsData: [VisitDetailData] = []
    @State private var currentGroupName: String? = nil

    /// ラベル名→色のマップ（labelOptions から構築）
    private var labelColorMap: [String: Color] { labelOptions.colorMap }

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
                detailContent
            }

            // 写真全画面表示オーバーレイ
            if let index = photoFullScreenIndex {
                Color.clear
                    .ignoresSafeArea()
                    .overlay(
                        PhotoPager(
                            paths: data.photoPaths,
                            startIndex: index,
                            externalDragOffset: $photoDragOffset,
                            onDismiss: { photoFullScreenIndex = nil }
                        )
                        .ignoresSafeArea()
                    )
                    .transition(.opacity)
                    .zIndex(1000)
            }
        }
        // ▼ 標準の戻るボタンを活かしつつ、右側に「編集」を出す
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(photoFullScreenIndex == nil || photoDragOffset != 0 ? .visible : .hidden, for: .navigationBar)
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
        // タクソノミー詳細画面への遷移
        .navigationDestination(item: $selectedLabel) { label in
            LabelDetailView(label: label) { updated, deleted in
                selectedLabel = nil
                if !deleted {
                    onUpdate()
                }
            }
        }
        .navigationDestination(item: $selectedGroup) { group in
            GroupDetailView(group: group) { updated, deleted in
                selectedGroup = nil
                if !deleted {
                    onUpdate()
                }
            }
        }
        .navigationDestination(item: $selectedMember) { member in
            MemberDetailView(member: member) { updated, deleted in
                selectedMember = nil
                if !deleted {
                    onUpdate()
                }
            }
        }
        .task {
            await loadTaxonomyData()
            await loadNearbyVisits()
            await loadSameGroupVisits()
        }
        .onChange(of: photoFullScreenIndex) { oldValue, newValue in
            if newValue != nil {
                // 写真が開いた時: フッターを非表示
                appUIState.tabBarOpacity = 0
                appUIState.isTabBarHidden = true
            } else {
                // 写真が閉じた時: フッターを表示
                appUIState.tabBarOpacity = 1
                appUIState.isTabBarHidden = false
                photoDragOffset = 0  // リセット
            }
        }
        .onChange(of: photoDragOffset) { oldValue, newValue in
            // ドラッグ中: ドラッグ量に応じてフッターをフェードイン
            if photoFullScreenIndex != nil {
                let progress = min(abs(newValue) / 150, 1.0)
                appUIState.tabBarOpacity = progress
            }
        }
        .onDisappear {
            // 画面を離れる時はタブバーを表示
            appUIState.isTabBarHidden = false
            appUIState.tabBarOpacity = 1
        }
    }

    // MARK: - Detail Content
    private var detailContent: some View {
        VisitDetailContent(
            data: data,
            mapSnapshot: nil,
            isSharing: false,
            nearbyVisits: nearbyVisits,
            nearbyVisitsData: nearbyVisitsData,
            sameGroupVisits: sameGroupVisits,
            sameGroupVisitsData: sameGroupVisitsData,
            currentGroupName: currentGroupName,
            onLabelTap: handleLabelTap,
            onGroupTap: handleGroupTap,
            onMemberTap: handleMemberTap,
            onMapTap: handleMapTap,
            labelColorMap: labelColorMap,
            photoFullScreenIndex: $photoFullScreenIndex
        )
    }

    // MARK: - Tap Handlers
    private func handleLabelTap(_ labelName: String) {
        if let label = labelOptions.first(where: { $0.name == labelName }) {
            selectedLabel = label
        }
    }

    private func handleGroupTap(_ groupName: String) {
        if let group = groupOptions.first(where: { $0.name == groupName }) {
            selectedGroup = group
        }
    }

    private func handleMemberTap(_ memberName: String) {
        if let member = memberOptions.first(where: { $0.name == memberName }) {
            selectedMember = member
        }
    }

    private func handleMapTap() {
        dismiss()
        onMapTap?()
    }

    // MARK: - データロード
    private func loadTaxonomyData() async {
        labelOptions = ((try? AppContainer.shared.repo.allLabels()) ?? []).sortedByName
        groupOptions = ((try? AppContainer.shared.repo.allGroups()) ?? []).sortedByName
        memberOptions = ((try? AppContainer.shared.repo.allMembers()) ?? []).sortedByName
    }

    private func loadNearbyVisits() async {
        let repo = AppContainer.shared.repo
        guard let currentVisit = try? repo.get(by: visitId) else { return }

        do {
            let nearby = try repo.fetchNearby(
                latitude: currentVisit.visit.latitude,
                longitude: currentVisit.visit.longitude,
                radius: 100.0,
                excludingId: visitId,
                limit: nil  // 制限なし、すべて表示
            )
            // 日付順、降順でソート
            nearbyVisits = nearby.sorted { $0.visit.timestampUTC > $1.visit.timestampUTC }
            nearbyVisitsData = nearbyVisits.map { toDetailData($0) }
        } catch {
            Logger.error("Failed to fetch nearby visits", error: error)
        }
    }

    private func loadSameGroupVisits() async {
        let repo = AppContainer.shared.repo
        guard let currentVisit = try? repo.get(by: visitId) else { return }
        guard let groupId = currentVisit.details.groupId else { return }

        // グループ名を取得
        currentGroupName = groupOptions.first(where: { $0.id == groupId })?.name

        do {
            let visits = try repo.fetchAll(
                filterLabel: nil,
                filterGroup: groupId,
                filterMember: nil,
                titleQuery: nil,
                dateFrom: nil,
                dateToExclusive: nil
            )

            // 現在の記録を除外し、日付順（降順）でソート
            sameGroupVisits = visits
                .filter { $0.visit.id != visitId }
                .sorted { $0.visit.timestampUTC > $1.visit.timestampUTC }

            sameGroupVisitsData = sameGroupVisits.map { toDetailData($0) }
        } catch {
            Logger.error("Failed to fetch same group visits", error: error)
        }
    }

    private func toDetailData(_ agg: VisitAggregate) -> VisitDetailData {
        let title: String = {
            let t = agg.details.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let t, !t.isEmpty { return t }
            if let f = agg.details.facilityName, !f.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return f }
            return L.Home.noTitle
        }()

        let labels: [String] = agg.details.labelIds.compactMap { id in
            labelOptions.first(where: { $0.id == id })?.name
        }
        let group: String? = agg.details.groupId.flatMap { id in
            groupOptions.first(where: { $0.id == id })?.name
        }
        let members: [String] = agg.details.memberIds.compactMap { id in
            memberOptions.first(where: { $0.id == id })?.name
        }

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
                VisitDetailContent(
                    data: data,
                    mapSnapshot: mapImage,
                    isSharing: true,
                    nearbyVisits: [],  // 共有時は近くの記録は含めない
                    nearbyVisitsData: [],
                    sameGroupVisits: [],  // 共有時はグループ記録は含めない
                    sameGroupVisitsData: [],
                    currentGroupName: nil,
                    labelColorMap: labelColorMap,
                    photoFullScreenIndex: .constant(nil)
                )
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
    var isManualEntry: Bool = false  // 後付け記録かどうか
}


struct SharePayload: Identifiable {
    let id = UUID()
    let image: UIImage
    let text: String
}
