import SwiftUI
import MapKit
import CoreLocation
import Photos

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

    // 共有プレビュー
    @State private var showSharePreview = false

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

            // 写真ライトボックス（地図のスポット/記録写真タップと同じ、
            // 暗転オーバーレイ + フェード&スケールで出す見せ方。保存ボタンのみ右上に残す）
            if let index = photoFullScreenIndex {
                VisitPhotoLightboxView(
                    paths: data.photoPaths,
                    startIndex: index,
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            photoFullScreenIndex = nil
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
                .zIndex(1000)
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
                    showSharePreview = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text(L.Common.share)
                    }
                    .font(.subheadline.weight(.semibold))
                }

                Button(role: .destructive) {
                    onDelete()
                    dismiss()
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel(L.Common.delete)
            }
        }

        .sheet(isPresented: $showSharePreview) {
            VisitSharePreviewSheet(data: data)
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
        .onChange(of: photoFullScreenIndex) { _, newValue in
            // 手動記録のフローティングボタンがライトボックスより手前に出てしまうため、
            // 開閉に合わせてRootTabView側で非表示にする
            appUIState.isPhotoLightboxVisible = (newValue != nil)
        }
        .onDisappear {
            // 画面を離れる時はタブバーを表示
            appUIState.isTabBarHidden = false
            appUIState.tabBarOpacity = 1
            appUIState.isPhotoLightboxVisible = false
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
            photoFullScreenIndex: animatedPhotoFullScreenIndex
        )
    }

    // MARK: - 地図タップ（dismiss を使うため View に残す）
    private func handleMapTap() {
        dismiss()
        onMapTap?()
    }

    // 写真を開く操作(PhotoReadOnlyGrid内のタップ)はwithAnimationでラップされていないため、
    // ここでBindingのsetterごしに包み、開閉どちらもフェード&スケールのtransitionが効くようにする
    private var animatedPhotoFullScreenIndex: Binding<Int?> {
        Binding(
            get: { photoFullScreenIndex },
            set: { newValue in
                withAnimation(.easeInOut(duration: 0.2)) {
                    photoFullScreenIndex = newValue
                }
            }
        )
    }
}

// MARK: - 写真ライトボックス

/// 記録詳細画面の写真タップ時の拡大表示。地図のスポット/記録写真タップと同じ
/// 暗転オーバーレイ+タップで閉じるシンプルな見せ方に統一しつつ、
/// 複数枚のスワイプ閲覧と、カメラロールへの保存ボタンだけは維持する
private struct VisitPhotoLightboxView: View {
    let paths: [String]
    let onDismiss: () -> Void
    @State private var currentIndex: Int
    @State private var showSavedToast = false

    init(paths: [String], startIndex: Int, onDismiss: @escaping () -> Void) {
        self.paths = paths
        self.onDismiss = onDismiss
        _currentIndex = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(paths.indices, id: \.self) { index in
                    Group {
                        if let uiImage = ImageStore.load(paths[index]) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .padding(24)
                        } else {
                            Color.clear
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: paths.count > 1 ? .always : .never))
            .ignoresSafeArea()

            // 保存ボタン・トーストはセーフエリアに従わせ、ノッチ/Dynamic Islandを避ける
            VStack {
                HStack {
                    Spacer()
                    Button {
                        saveCurrentPhoto()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.black.opacity(0.45), in: Circle())
                            .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1))
                    }
                    .padding(.trailing, 16)
                }

                if showSavedToast {
                    Text(L.Common.photoSaved)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.8), in: Capsule())
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                }

                Spacer()
            }
            .padding(.top, 12)
        }
        .statusBarHidden(true)
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
    }

    private func saveCurrentPhoto() {
        guard paths.indices.contains(currentIndex),
              let img = ImageStore.load(paths[currentIndex]) else { return }
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: img)
            }) { success, _ in
                guard success else { return }
                DispatchQueue.main.async {
                    withAnimation { showSavedToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { showSavedToast = false }
                    }
                }
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


