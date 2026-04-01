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

    // Store（ビジネスロジック・状態管理）
    @State private var store = VisitDetailStore()

    // 地図カメラ（View固有のUI状態）
    @State private var camera: MapCameraPosition

    // 写真全画面表示用（View固有のUI状態）
    @State private var photoFullScreenIndex: Int? = nil
    @State private var photoDragOffset: CGFloat = 0

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
                    Task { await store.makeAndShare(data: data) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text(L.Common.share)
                    }
                    .font(.subheadline.weight(.semibold))
                }

                Button(role: .destructive) {
                    store.showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel(L.Common.delete)
            }
        }

        .sheet(item: $store.sharePayload) { payload in
            ActivityView(items: [payload.text, payload.image])
        }
        .alert(L.Detail.deleteConfirmTitle, isPresented: $store.showDeleteAlert) {
            Button(L.Common.delete, role: .destructive) {
                onDelete()
                dismiss()
            }
            Button(L.Common.cancel, role: .cancel) { }
        } message: {
            Text(L.Detail.deleteConfirmMessage)
        }
        // タクソノミー詳細画面への遷移
        .navigationDestination(item: $store.selectedLabel) { label in
            LabelDetailView(label: label) { updated, deleted in
                store.selectedLabel = nil
                if !deleted {
                    onUpdate()
                }
            }
        }
        .navigationDestination(item: $store.selectedGroup) { group in
            GroupDetailView(group: group) { updated, deleted in
                store.selectedGroup = nil
                if !deleted {
                    onUpdate()
                }
            }
        }
        .navigationDestination(item: $store.selectedMember) { member in
            MemberDetailView(member: member) { updated, deleted in
                store.selectedMember = nil
                if !deleted {
                    onUpdate()
                }
            }
        }
        .task {
            await store.loadTaxonomyData()
            await store.loadNearbyVisits(visitId: visitId)
            await store.loadSameGroupVisits(visitId: visitId)
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
            nearbyVisits: store.nearbyVisits,
            nearbyVisitsData: store.nearbyVisitsData,
            sameGroupVisits: store.sameGroupVisits,
            sameGroupVisitsData: store.sameGroupVisitsData,
            currentGroupName: store.currentGroupName,
            onLabelTap: store.handleLabelTap,
            onGroupTap: store.handleGroupTap,
            onMemberTap: store.handleMemberTap,
            onMapTap: handleMapTap,
            labelColorMap: store.labelColorMap,
            photoFullScreenIndex: $photoFullScreenIndex
        )
    }

    // MARK: - 地図タップ（dismiss を使うため View に残す）
    private func handleMapTap() {
        dismiss()
        onMapTap?()
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
