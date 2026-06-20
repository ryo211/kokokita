import SwiftUI
import MapKit
import CoreLocation

/// 地図とリストの表示レイアウトモード
private enum SpotListLayout: CaseIterable {
    case mapOnly   // 地図のみ
    case split     // 地図50% / 一覧50%
    case listOnly  // 一覧のみ

    var icon: String {
        switch self {
        case .mapOnly:  return "map"
        case .split:    return "rectangle.split.1x2"
        case .listOnly: return "list.bullet"
        }
    }
}

// スポット一覧画面
// 近くのスポット / お気に入り / 行ったスポット の3モードを切り替えられる地図ベースのスポット一覧
struct SpotListScreen: View {
    // MARK: - 設定

    /// 初期表示モード（タブからの起動はデフォルト、ホーム「全てを見る」から指定）
    let initialMode: SpotListMode
    /// NavigationStack 内に埋め込まれる場合 true（ホームからの遷移用）
    let isEmbedded: Bool

    init(initialMode: SpotListMode = .nearby, isEmbedded: Bool = false) {
        self.initialMode = initialMode
        self.isEmbedded = isEmbedded
    }

    // MARK: - AppStorage キー
    private static let zoomOnSpotFocusKey = "spotList.zoomOnSpotFocus"
    private static let spotPhotoSizeKey = "spotList.spotPhotoSize"

    @State private var store = SpotListStore()
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedSpotId: UUID?
    /// 地図の現在中心（スクロール・ズームに追従）
    @State private var mapCenterCoordinate = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
    /// 確定済み選択地点の住所（逆ジオコーディング結果）
    @State private var selectedAddress: String?
    /// コース詳細へのナビゲーション
    @State private var courseDetailRoute: CourseRoute?
    /// 絞り込みパネル表示フラグ
    @State private var showFilter = false
    /// スポット一覧スライド方向（新コンテンツの挿入 edge）
    @State private var listTransitionEdge: Edge = .trailing
    /// 地図・一覧のレイアウト
    @State private var viewLayout: SpotListLayout = .split
    /// スワイプ二重発火防止フラグ
    @State private var layoutSwipeConsumed = false

    // 検索状態（View ローカル）
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearchLoading = false
    @FocusState private var searchFocused: Bool

    // フォーカス機能
    @AppStorage("spotList.zoomOnSpotFocus") private var zoomOnSpotFocus = false
    @AppStorage("spotList.spotPhotoSize") private var spotPhotoSizeRaw = CourseSpotPhotoSize.medium.rawValue
    @State private var visibleMapSpan = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    @State private var selectedSpotScreenPoint: CGPoint? = nil
    @State private var showMapSettings = false
    @State private var expandedImageUrl: URL? = nil

    @Environment(\.spotFavoriteStore) private var favoriteStore

    /// 現在のスポット写真サイズ
    private var spotPhotoSize: CourseSpotPhotoSize {
        CourseSpotPhotoSize(rawValue: spotPhotoSizeRaw) ?? .medium
    }

    /// 地点選択が有効かどうか（近くのスポットモード、または距離ソート時）
    private var isLocationSelectionActive: Bool {
        store.listMode == .nearby || store.sortType == .distance
    }

    var body: some View {
        if isEmbedded {
            mainContent
                .navigationTitle(store.listMode.title)
                .navigationBarTitleDisplayMode(.inline)
        } else {
            NavigationStack {
                mainContent
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
    }

    // MARK: - メインコンテンツ

    private var mainContent: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    // 地図
                    if viewLayout == .mapOnly {
                        mapSection
                    } else if viewLayout == .split {
                        mapSection
                            .frame(height: geo.size.height * 0.5)
                    }

                    // レイアウト切替バー（常時表示）
                    layoutStrip

                    Divider()

                    // 一覧
                    if viewLayout != .mapOnly {
                        spotListSection
                    }
                }

                // 検索オーバーレイ
                if isSearching {
                    searchOverlay
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isSearching)
            .animation(.easeInOut(duration: 0.3), value: viewLayout)
        }
        .task {
            store.listMode = initialMode
            store.favoriteSpotIds = favoriteStore.favoriteSpotIds
            await store.load()
            initializeCamera()
        }
        .onChange(of: favoriteStore.favoriteSpotIds) { _, ids in
            store.favoriteSpotIds = ids
            store.recalculateNearbySpots()
        }
        .navigationDestination(item: $courseDetailRoute) { route in
            CourseDetailView(course: route.course, initialSelectedSpotId: route.initialSpotId)
        }
        .onChange(of: spotPhotoSizeRaw) { _, _ in
            guard let spotId = selectedSpotId,
                  let item = store.nearbySpots.first(where: { $0.spot.id == spotId }),
                  item.spot.hasValidCoordinate else { return }
            let center = focusCenter(
                latitude: item.spot.latitude,
                longitude: item.spot.longitude,
                span: visibleMapSpan
            )
            withAnimation(.easeInOut(duration: 0.3)) {
                cameraPosition = .region(MKCoordinateRegion(center: center, span: visibleMapSpan))
            }
        }
        .sheet(isPresented: $showMapSettings) {
            CourseMapSettingsSheet(
                zoomOnSpotFocus: $zoomOnSpotFocus,
                spotPhotoSizeRaw: $spotPhotoSizeRaw
            )
        }
        .overlay {
            if let url = expandedImageUrl {
                ZStack {
                    Color.black.opacity(0.65).ignoresSafeArea()
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image
                                .resizable()
                                .scaledToFit()
                                .padding(32)
                                .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 8)
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) { expandedImageUrl = nil }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: expandedImageUrl != nil)
    }

    // MARK: - 地図セクション

    private var mapSection: some View {
        ZStack(alignment: .top) {
            MapReader { proxy in
                Map(position: $cameraPosition, interactionModes: [.pan, .zoom, .pitch]) {
                    // 非選択ピンを先に描画（z-order: 下）
                    ForEach(Array(store.nearbySpots.enumerated()), id: \.element.spot.id) { index, item in
                        if item.spot.hasValidCoordinate {
                            let coord = CLLocationCoordinate2D(
                                latitude: item.spot.latitude,
                                longitude: item.spot.longitude
                            )
                            Annotation("", coordinate: coord, anchor: .center) {
                                SpotPinView(
                                    orderNumber: index + 1,
                                    isCheckedIn: item.spot.isCheckedIn,
                                    isSelected: false
                                )
                                .onTapGesture { focusOrUnfocus(item: item) }
                            }
                        }
                    }

                    // 認識半径サークル（選択時のみ）
                    // 選択ピン自体は Map 外の SwiftUI overlay で描画（z-order 保証のため）
                    if let selectedId = selectedSpotId,
                       let entry = store.nearbySpots.enumerated().first(where: { $0.element.spot.id == selectedId }),
                       entry.element.spot.hasValidCoordinate {
                        let item = entry.element
                        let coord = CLLocationCoordinate2D(
                            latitude: item.spot.latitude,
                            longitude: item.spot.longitude
                        )
                        MapCircle(center: coord, radius: item.spot.recognitionRadiusMeters ?? item.course.recognitionRadiusMeters)
                            .foregroundStyle(Color.indigo.opacity(0.08))
                            .stroke(Color.indigo.opacity(0.5), lineWidth: 1.5)
                    }

                    // 確定済み選択地点ピン（地点選択が有効なモードのみ）
                    if isLocationSelectionActive, let coord = store.selectedCoordinate {
                        Annotation("", coordinate: coord, anchor: .bottom) {
                            selectedPinView
                        }
                    }
                }
                .mapStyle(.standard(emphasis: .muted))
                .mapControls {
                    MapCompass()
                    MapScaleView()
                }
                .onChange(of: selectedSpotId) { _, _ in selectedSpotScreenPoint = nil }
                .task(id: selectedSpotId) {
                    guard selectedSpotId != nil else { return }
                    try? await Task.sleep(nanoseconds: 180_000_000)
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.2)) { updateSpotScreenPoint(proxy: proxy) }
                    }
                    try? await Task.sleep(nanoseconds: 320_000_000)
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        if selectedSpotScreenPoint == nil {
                            withAnimation(.easeInOut(duration: 0.2)) { updateSpotScreenPoint(proxy: proxy) }
                        }
                    }
                }
                .onMapCameraChange(frequency: .onEnd) { ctx in
                    visibleMapSpan = ctx.region.span
                    mapCenterCoordinate = ctx.region.center
                    withAnimation(.easeInOut(duration: 0.2)) { updateSpotScreenPoint(proxy: proxy) }
                }
                .onMapCameraChange(frequency: .continuous) { ctx in
                    visibleMapSpan = ctx.region.span
                    mapCenterCoordinate = ctx.region.center
                    guard selectedSpotScreenPoint != nil else { return }
                    updateSpotScreenPoint(proxy: proxy)
                }
                // 照準（地点選択が有効なモードのみ）
                .overlay(alignment: .center) {
                    if isLocationSelectionActive {
                        crosshairView
                    }
                }
                // 地図設定ボタン（右上）
                .overlay(alignment: .topTrailing) {
                    mapSettingsButton.padding(12)
                }
                // モード切替タブ（左上）
                .overlay(alignment: .topLeading) {
                    spotModeTabsView
                        .padding(.top, 12)
                }
                // 「この場所を選択」ボタン（右下・地点選択が有効なモードのみ）
                .overlay(alignment: .bottomTrailing) {
                    if isLocationSelectionActive {
                        selectLocationButton
                            .padding(.horizontal, 12)
                            .padding(.bottom, 12)
                    }
                }
                // リーダーライン＋スポット画像
                .overlay { leaderLineOverlay }
                // 選択ピンを SwiftUI overlay として最前面に描画（MapKit z-order に依存しない）
                .overlay {
                    if let spotPoint = selectedSpotScreenPoint,
                       let entry = store.nearbySpots.enumerated().first(where: { $0.element.spot.id == selectedSpotId }),
                       entry.element.spot.hasValidCoordinate {
                        SpotPinView(
                            orderNumber: entry.offset + 1,
                            isCheckedIn: entry.element.spot.isCheckedIn,
                            isSelected: true
                        )
                        .onTapGesture { focusOrUnfocus(item: entry.element) }
                        .position(spotPoint)
                    }
                }
            }
        }
    }

    // MARK: - モード切替タブ（左側付箋UI）

    private var spotModeTabsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(SpotListMode.allCases.enumerated()), id: \.element) { index, mode in
                let isSelected = store.listMode == mode
                SpotModeTabButton(mode: mode, isSelected: isSelected) {
                    switchMode(to: mode)
                }
                .zIndex(isSelected ? 10 : Double(SpotListMode.allCases.count - index))
            }
        }
    }

    private func switchMode(to mode: SpotListMode) {
        guard store.listMode != mode else { return }
        // タブボタン押下: インデックスの大小でスライド方向を決定
        let allModes = SpotListMode.allCases
        if let currentIdx = allModes.firstIndex(of: store.listMode),
           let newIdx = allModes.firstIndex(of: mode) {
            listTransitionEdge = newIdx > currentIdx ? .trailing : .leading
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            selectedSpotId = nil
            selectedSpotScreenPoint = nil
            showFilter = false
            store.listMode = mode
            store.sortType = .added
            store.recalculateNearbySpots()
        }
        fitAllPoints()
    }

    // MARK: - フォーカス同期

    private func focusOrUnfocus(item: (course: Course, spot: CourseSpot, distance: Double)) {
        let spot = item.spot
        withAnimation(.easeInOut(duration: 0.3)) {
            if selectedSpotId == spot.id {
                selectedSpotId = nil
                selectedSpotScreenPoint = nil
                fitAllPoints()
            } else {
                selectedSpotId = spot.id
                selectedSpotScreenPoint = nil
                guard spot.hasValidCoordinate else { return }
                let radius = spot.recognitionRadiusMeters ?? item.course.recognitionRadiusMeters
                let span = zoomOnSpotFocus ? spotSpan(recognitionRadius: radius) : visibleMapSpan
                let center = focusCenter(latitude: spot.latitude, longitude: spot.longitude, span: span)
                cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
            }
        }
    }

    private func spotSpan(recognitionRadius: Double) -> MKCoordinateSpan {
        let diameterDegrees = (recognitionRadius * 2) / 111_000.0
        let delta = max(0.002, min(diameterDegrees * 2.5, 0.3))
        return MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)
    }

    private func focusCenter(latitude: Double, longitude: Double, span: MKCoordinateSpan) -> CLLocationCoordinate2D {
        guard spotPhotoSize == .large else {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        return CLLocationCoordinate2D(
            latitude: min(90, latitude + span.latitudeDelta * 0.25),
            longitude: longitude
        )
    }

    private func updateSpotScreenPoint(proxy: MapProxy) {
        guard let spotId = selectedSpotId,
              let item = store.nearbySpots.first(where: { $0.spot.id == spotId }),
              item.spot.hasValidCoordinate else {
            selectedSpotScreenPoint = nil
            return
        }
        let coord = CLLocationCoordinate2D(latitude: item.spot.latitude, longitude: item.spot.longitude)
        selectedSpotScreenPoint = proxy.convert(coord, to: .local)
    }

    // MARK: - リーダーライン＋スポット画像オーバーレイ

    @ViewBuilder
    private var leaderLineOverlay: some View {
        if spotPhotoSize != .none,
           let spotPoint = selectedSpotScreenPoint,
           let item = store.nearbySpots.first(where: { $0.spot.id == selectedSpotId }) {
            let spot = item.spot
            let localImage = spot.localCoverImagePath.flatMap { LocalImageStorage.shared.load(from: $0) }
            let remoteUrl = spot.coverImageUrl.flatMap { URL(string: $0) }
            if localImage != nil || remoteUrl != nil {
                SpotLeaderLineView(
                    spotPoint: spotPoint,
                    size: spotPhotoSize,
                    localImage: localImage,
                    imageUrl: remoteUrl
                ) {
                    if let url = remoteUrl {
                        withAnimation(.easeInOut(duration: 0.2)) { expandedImageUrl = url }
                    }
                }
                .transition(.opacity)
            }
        }
    }

    // MARK: - 地図設定ボタン

    private var mapSettingsButton: some View {
        Button { showMapSettings = true } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 14, weight: .medium))
                .frame(width: 36, height: 36)
                .background(.regularMaterial, in: Circle())
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var selectedPinView: some View {
        Image(systemName: "mappin")
            .font(.system(size: 32))
            .foregroundStyle(.indigo)
            .shadow(radius: 4)
    }

    private var crosshairView: some View {
        ZStack {
            Rectangle().fill(Color.indigo.opacity(0.6)).frame(width: 18, height: 1.5)
            Rectangle().fill(Color.indigo.opacity(0.6)).frame(width: 1.5, height: 18)
            Circle().fill(Color.indigo.opacity(0.8)).frame(width: 4, height: 4)
        }
        .allowsHitTesting(false)
    }

    // 右下ボタン群（現在地 + この場所を選択）
    private var selectLocationButton: some View {
        HStack(spacing: 8) {
            Button { moveToCurrentLocation() } label: {
                Image(systemName: "location.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.indigo)
                    .padding(8)
                    .background(.regularMaterial, in: Circle())
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            Button { selectMapCenter() } label: {
                Text(L.SpotEditor.selectLocation)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.indigo, in: Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
    }

    // 表示件数ドロップダウン（近くのスポットモード用）
    private var spotCountButton: some View {
        Menu {
            ForEach([10, 20, 30, 50], id: \.self) { n in
                Button {
                    store.displayLimit = n
                    store.recalculateNearbySpots()
                    fitAllPoints()
                } label: {
                    if store.displayLimit == n {
                        Label("\(n)件", systemImage: "checkmark")
                    } else {
                        Text("\(n)件")
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text("\(store.displayLimit)件")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(.indigo)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // ソートタイプ選択（お気に入り・行ったモード用）
    private var sortTypeSelector: some View {
        HStack(spacing: 4) {
            sortChip(label: L.SpotList.sortTypeAdded, isSelected: store.sortType == .added) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    store.sortType = .added
                    store.recalculateNearbySpots()
                    fitAllPoints()
                }
            }
            sortChip(label: L.Course.sortDistance, isSelected: store.sortType == .distance) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    store.sortType = .distance
                    if store.selectedCoordinate == nil { moveToCurrentLocation() }
                    store.recalculateNearbySpots()
                    fitAllPoints()
                }
            }
        }
    }

    private func sortChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    isSelected ? AnyShapeStyle(Color.indigo) : AnyShapeStyle(Color.secondary.opacity(0.12)),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    // MARK: - スポット一覧セクション

    private var spotListSection: some View {
        ZStack(alignment: .bottom) {
            // リスト本体: モード変更時にカードスライドアニメーション
            Group {
                if store.isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.nearbySpots.isEmpty {
                    emptyView
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(store.nearbySpots.enumerated()), id: \.element.spot.id) { index, item in
                                    SpotListRowView(
                                        spot: item.spot,
                                        course: item.course,
                                        orderNumber: index + 1,
                                        isSelected: selectedSpotId == item.spot.id,
                                        distance: isLocationSelectionActive ? item.distance : nil,
                                        onCourseTap: { courseDetailRoute = CourseRoute(course: item.course, initialSpotId: item.spot.id) }
                                    )
                                    .id(item.spot.id)
                                    .contentShape(Rectangle())
                                    .onTapGesture { focusOrUnfocus(item: item) }
                                    if index < store.nearbySpots.count - 1 {
                                        Divider().padding(.leading, 60)
                                    }
                                }
                            }
                        }
                        .onChange(of: selectedSpotId) { _, newId in
                            if let id = newId {
                                withAnimation { proxy.scrollTo(id, anchor: .top) }
                            }
                        }
                    }
                }
            }
            // モード切替でスライドアニメーション
            .id(store.listMode)
            .transition(.asymmetric(
                insertion: .move(edge: listTransitionEdge),
                removal: .move(edge: listTransitionEdge == .trailing ? .leading : .trailing)
            ))

            // 絞り込みボタン（全モード共通）
            if !showFilter {
                HStack {
                    Spacer()
                    filterButton
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                }
            }

            if showFilter {
                SpotFilterPanel(store: store) {
                    withAnimation(.spring(duration: 0.35, bounce: 0.05)) { showFilter = false }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.28), value: store.listMode)
        .animation(.spring(duration: 0.35, bounce: 0.05), value: showFilter)
        .clipped()
        // 横スワイプでモード循環切り替え（縦スクロールとは独立して動作）
        .simultaneousGesture(
            DragGesture(minimumDistance: 40, coordinateSpace: .local)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) * 1.5,
                          abs(value.translation.width) > 40 else { return }
                    let allModes = SpotListMode.allCases
                    guard let currentIndex = allModes.firstIndex(of: store.listMode) else { return }
                    if value.translation.width < 0 {
                        // 左スワイプ → 次のモード（新コンテンツは右から）
                        listTransitionEdge = .trailing
                        switchMode(to: allModes[(currentIndex + 1) % allModes.count])
                    } else {
                        // 右スワイプ → 前のモード（新コンテンツは左から）
                        listTransitionEdge = .leading
                        switchMode(to: allModes[(currentIndex - 1 + allModes.count) % allModes.count])
                    }
                }
        )
    }

    private var filterButton: some View {
        Button {
            withAnimation(.spring(duration: 0.35, bounce: 0.05)) { showFilter = true }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.indigo, in: Circle())
                .shadow(color: Color.indigo.opacity(0.45), radius: 8, x: 0, y: 4)
                .overlay(alignment: .topTrailing) {
                    if !store.excludedCourseIds.isEmpty {
                        Circle().fill(Color.white).frame(width: 10, height: 10)
                            .overlay { Circle().fill(Color.indigo.opacity(0.7)).frame(width: 7, height: 7) }
                            .offset(x: 2, y: -2)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(emptyMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var emptyMessage: String {
        switch store.listMode {
        case .nearby:
            return store.selectedCoordinate == nil ? L.SpotList.locationUnavailable : L.SpotList.noSpots
        case .favorites:
            if store.sortType == .distance && store.selectedCoordinate == nil {
                return L.SpotList.locationUnavailable
            }
            return L.SpotList.noFavorites
        case .visited:
            if store.sortType == .distance && store.selectedCoordinate == nil {
                return L.SpotList.locationUnavailable
            }
            return L.SpotList.noVisited
        }
    }

    // MARK: - 検索オーバーレイ

    private var searchOverlay: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { exitSearch() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

                ZStack(alignment: .trailing) {
                    TextField(L.SpotEditor.searchPlaceholder, text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .focused($searchFocused)
                        .submitLabel(.search)
                        .padding(.trailing, searchText.isEmpty ? 0 : 24)
                        .onSubmit {
                            let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !q.isEmpty else { return }
                            Task { await performSearch(query: q) }
                        }
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))

            Divider()

            if isSearchLoading {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.8)
                    Text(L.Common.loading).font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(searchResults, id: \.self) { item in
                            Button { selectFromSearch(item) } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "mappin.circle").foregroundStyle(.indigo).font(.title3).frame(width: 32)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name ?? "").font(.subheadline).foregroundStyle(.primary)
                                        if let addr = item.placemark.thoroughfare {
                                            Text(addr).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 60)
                        }
                    }
                }
                .background(Color(.systemBackground))
            }
        }
        .background(Color(.systemBackground))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - レイアウト切替バー

    private var layoutStrip: some View {
        HStack(alignment: .center, spacing: 8) {
            // 左側: モードに応じたコンテンツ
            if isLocationSelectionActive {
                locationAreaContent
            } else {
                totalCountContent
            }

            Spacer()

            // 右側: 近くのスポットは件数設定、その他はソートタイプ選択
            if store.listMode == .nearby {
                spotCountButton
            } else {
                sortTypeSelector
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 5, coordinateSpace: .local)
                .onChanged { value in
                    guard !layoutSwipeConsumed else { return }
                    if value.translation.height < -15 {
                        layoutSwipeConsumed = true
                        switchLayout(true)
                    } else if value.translation.height > 15 {
                        layoutSwipeConsumed = true
                        switchLayout(false)
                    }
                }
                .onEnded { _ in layoutSwipeConsumed = false }
        )
    }

    // 住所カード（近くのスポットモード or 近い順ソート時）
    @ViewBuilder
    private var locationAreaContent: some View {
        // 虫眼鏡アイコン（場所検索）
        Button {
            withAnimation(.easeInOut(duration: 0.25)) { isSearching = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { searchFocused = true }
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.indigo)
                .frame(width: 32, height: 32)
                .background(.regularMaterial, in: Circle())
                .overlay { Circle().strokeBorder(Color.indigo.opacity(0.25), lineWidth: 0.8) }
                .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)

        // 住所カード + サブタイトル
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.indigo)
                Text(selectedAddress ?? store.selectedLocationName ?? "現在地")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.indigo.opacity(0.25), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
            .id(selectedAddress ?? store.selectedLocationName ?? "")
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
            .animation(.easeInOut(duration: 0.25), value: selectedAddress)

            Text(store.listMode == .nearby ? L.SpotList.nearbySubtitle : L.SpotList.distanceSubtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
        }
    }

    // 全件数表示（追加順ソート時）
    private var totalCountContent: some View {
        HStack(spacing: 6) {
            Image(systemName: store.listMode.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.indigo)
            Text(L.SpotList.totalCount(store.nearbySpots.count))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.indigo.opacity(0.2), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
    }

    private func switchLayout(_ isUp: Bool) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if isUp {
                switch viewLayout {
                case .mapOnly:  viewLayout = .split
                case .split:    viewLayout = .listOnly
                case .listOnly: break
                }
            } else {
                switch viewLayout {
                case .mapOnly:  break
                case .split:    viewLayout = .mapOnly
                case .listOnly: viewLayout = .split
                }
            }
        }
    }

    // MARK: - ヘルパー

    private func moveToCurrentLocation() {
        guard let coord = CLLocationManager().location?.coordinate else { return }
        store.updateSelectedLocation(coord, name: nil)
        selectedAddress = nil
        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        }
        fitAllPoints()
        Task { await reverseGeocode(coordinate: coord) }
    }

    private func selectMapCenter() {
        let coord = mapCenterCoordinate
        store.updateSelectedLocation(coord, name: nil)
        selectedAddress = nil
        fitAllPoints()
        Task { await reverseGeocode(coordinate: coord) }
    }

    private func selectFromSearch(_ item: MKMapItem) {
        exitSearch()
        let coord = item.placemark.coordinate
        store.updateSelectedLocation(coord, name: item.name)
        selectedAddress = nil
        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        }
        fitAllPoints()
        Task { await reverseGeocode(coordinate: coord) }
    }

    private func exitSearch() {
        searchFocused = false
        withAnimation(.easeInOut(duration: 0.25)) { isSearching = false }
        searchText = ""
        searchResults = []
    }

    private func performSearch(query: String) async {
        isSearchLoading = true
        defer { isSearchLoading = false }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let response = try? await MKLocalSearch(request: request).start() {
            searchResults = response.mapItems
        } else {
            searchResults = []
        }
    }

    private func initializeCamera() {
        fitAllPoints()
        if let coord = store.selectedCoordinate, isLocationSelectionActive {
            Task { await reverseGeocode(coordinate: coord) }
        }
    }

    private func reverseGeocode(coordinate: CLLocationCoordinate2D) async {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let pm = try? await geocoder.reverseGeocodeLocation(location).first else { return }

        var parts: [String] = []
        if let adminArea = pm.administrativeArea { parts.append(adminArea) }
        if let subAdmin = pm.subAdministrativeArea { parts.append(subAdmin) }
        if let locality = pm.locality { parts.append(locality) }
        if let subLocality = pm.subLocality { parts.append(subLocality) }
        if let thoroughfare = pm.thoroughfare { parts.append(thoroughfare) }
        if let subThoroughfare = pm.subThoroughfare { parts.append(subThoroughfare) }

        let result = parts.joined()
        if !result.isEmpty { selectedAddress = result }
    }

    /// 全スポットが収まるようにカメラをフィット（モードに応じて中心を算出）
    private func fitAllPoints() {
        let spots = store.nearbySpots
        guard !spots.isEmpty else {
            if let center = store.selectedCoordinate {
                withAnimation {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: center,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    ))
                }
            }
            return
        }

        // 地点選択が有効かつ座標がある場合はその座標を中心に、そうでなければスポット群の重心を使用
        let center: CLLocationCoordinate2D
        if isLocationSelectionActive, let coord = store.selectedCoordinate {
            center = coord
        } else {
            let validSpots = spots.filter { $0.spot.hasValidCoordinate }
            guard !validSpots.isEmpty else { return }
            let avgLat = validSpots.map { $0.spot.latitude }.reduce(0, +) / Double(validSpots.count)
            let avgLon = validSpots.map { $0.spot.longitude }.reduce(0, +) / Double(validSpots.count)
            center = CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
        }

        var maxLatDelta: CLLocationDegrees = 0.005
        var maxLonDelta: CLLocationDegrees = 0.005
        for item in spots where item.spot.hasValidCoordinate {
            maxLatDelta = max(maxLatDelta, abs(item.spot.latitude  - center.latitude))
            maxLonDelta = max(maxLonDelta, abs(item.spot.longitude - center.longitude))
        }

        let spanLat = max(maxLatDelta * 2.4, 0.01)
        let spanLon = max(maxLonDelta * 2.4, 0.01)

        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
            ))
        }
    }
}

// MARK: - モード切替タブボタン（左側付箋スタイル）

private struct SpotModeTabButton: View {
    let mode: SpotListMode
    let isSelected: Bool
    let action: () -> Void

    private let selectedWidth: CGFloat = 104
    private let unselectedWidth: CGFloat = 80
    /// 全 SF Symbol を同じ幅で並べてテキスト開始位置を揃える
    private let iconWidth: CGFloat = 14
    /// 全モード・選択状態で統一フォントサイズ（minimumScaleFactor を使わない）
    private let fontSize: CGFloat = 11

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: mode.systemImage)
                    .font(.system(size: fontSize, weight: .semibold))
                    .frame(width: iconWidth, alignment: .center)
                Text(mode.shortTitle)
                    .font(.system(size: fontSize, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(width: isSelected ? selectedWidth : unselectedWidth, alignment: .leading)
            .background {
                if isSelected {
                    SpotModeTabShape().fill(Color.indigo)
                } else {
                    SpotModeTabShape().fill(.regularMaterial)
                }
            }
            .overlay {
                SpotModeTabShape()
                    .stroke(
                        isSelected ? Color.indigo.opacity(0.0) : Color.white.opacity(0.5),
                        lineWidth: 0.8
                    )
            }
            .shadow(
                color: isSelected ? Color.indigo.opacity(0.35) : Color.black.opacity(0.15),
                radius: isSelected ? 6 : 3,
                x: 2, y: 2
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isSelected)
    }
}

// 左側フラット・右側角丸の付箋シェイプ
private struct SpotModeTabShape: Shape {
    var cornerRadius: CGFloat = 10

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = min(cornerRadius, rect.height / 2)

        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: 0))
        path.addArc(
            center: CGPoint(x: rect.maxX - r, y: r),
            radius: r,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addArc(
            center: CGPoint(x: rect.maxX - r, y: rect.maxY - r),
            radius: r,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: 0, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - スポットピンビュー

private struct SpotPinView: View {
    let orderNumber: Int
    let isCheckedIn: Bool
    let isSelected: Bool

    private var size: CGFloat { isSelected ? 20 : 14 }

    var body: some View {
        ZStack {
            // フォーカス時のスポットライト（背後からの照射グロー）
            Circle()
                .fill(Color.indigo.opacity(0.38))
                .frame(width: 42, height: 42)
                .blur(radius: 9)
                .scaleEffect(isSelected ? 1 : 0.01)
                .opacity(isSelected ? 1 : 0)

            // 外縁（白リング + 影）
            Circle()
                .fill(Color.white)
                .frame(width: size + 5, height: size + 5)
                .shadow(color: .black.opacity(isSelected ? 0.4 : 0.25),
                        radius: isSelected ? 6 : 3, x: 0, y: 2)

            if isCheckedIn {
                // 達成済み：ゴールド + スター
                Circle()
                    .fill(Color(hue: 0.13, saturation: 0.85, brightness: 0.95))
                    .frame(width: size, height: size)
                Image(systemName: "star.fill")
                    .font(.system(size: isSelected ? 9 : 6, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                // 未達成：インディゴ + 番号
                Circle()
                    .fill(Color.indigo)
                    .frame(width: size, height: size)
                Text("\(orderNumber)")
                    .font(.system(size: isSelected ? 9 : 6, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .animation(.easeOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - スポット行ビュー

private struct SpotListRowView: View {
    let spot: CourseSpot
    let course: Course
    let orderNumber: Int
    let isSelected: Bool
    var distance: Double? = nil
    var onCourseTap: () -> Void = {}

    @Environment(\.spotFavoriteStore) private var favoriteStore

    private var distanceText: String? {
        guard let d = distance else { return nil }
        return d < 1000 ? String(format: "%.0fm", d) : String(format: "%.1fkm", d / 1000)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // 番号バッジ（達成済み: ゴールド★ / 未達成: インディゴ番号）
                ZStack {
                    Circle()
                        .fill(spot.isCheckedIn
                              ? Color(hue: 0.13, saturation: 0.85, brightness: 0.95)
                              : Color.indigo)
                        .frame(width: 32, height: 32)
                    if spot.isCheckedIn {
                        Image(systemName: "star.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Text("\(orderNumber)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Button(action: onCourseTap) {
                        HStack(spacing: 2) {
                            Text(course.title).font(.caption).lineLimit(1)
                            Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundStyle(.indigo)
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 6) {
                        Text(spot.name).font(.body)
                        if spot.isCheckedIn {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.body)
                                .foregroundStyle(Color.indigo)
                        }
                    }

                    if let text = distanceText {
                        HStack(spacing: 2) {
                            Image(systemName: "location.fill").font(.caption2)
                            Text(text).font(.caption2.bold().monospacedDigit())
                        }
                        .foregroundStyle(.indigo)
                        .padding(.top, 1)
                    }
                }

                Spacer()

                Button {
                    favoriteStore.toggle(spot.id)
                } label: {
                    Image(systemName: favoriteStore.isFavorite(spot.id) ? "heart.fill" : "heart")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(
                            favoriteStore.isFavorite(spot.id)
                                ? Color(red: 1.0, green: 0.42, blue: 0.62)
                                : Color.secondary.opacity(0.88)
                        )
                        .shadow(color: Color(uiColor: .systemBackground).opacity(0.9), radius: 1.5, x: 0, y: 0)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if isSelected {
                SpotRowExpandedView(spot: spot)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background { SpotRowBackdropView(spot: spot, isSelected: isSelected) }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - 展開詳細ビュー

private struct SpotRowExpandedView: View {
    let spot: CourseSpot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let iconWidth: CGFloat = 14

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "mappin.circle").font(.caption).frame(width: iconWidth)
                Text(spot.address ?? L.Course.noAddress).font(.caption).fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(spot.address != nil ? Color.secondary : Color.secondary.opacity(0.5))
            .padding(.leading, 60)
            .padding(.trailing, 16)

            if let date = spot.firstCheckedInAt {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "calendar.circle").font(.caption).frame(width: iconWidth)
                    Text(L.Course.visitedOn(date.formatted(date: .long, time: .omitted)))
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Color.indigo)
                .padding(.leading, 60)
                .padding(.trailing, 16)
            } else {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "calendar.circle").font(.caption).frame(width: iconWidth)
                    Text(L.Course.notVisited).font(.caption)
                }
                .foregroundStyle(Color.secondary)
                .padding(.leading, 60)
                .padding(.trailing, 16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 10)
    }
}

// MARK: - スポット行背景ビュー

private struct SpotRowBackdropView: View {
    let spot: CourseSpot
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var hasImage: Bool { spot.localCoverImagePath != nil || spot.coverImageUrl != nil }

    private var imageOpacity: Double {
        if colorScheme == .dark {
            return isSelected ? 0.82 : 0.72
        }
        return isSelected ? 0.62 : 0.50
    }

    private var trailingBackgroundOpacity: Double {
        colorScheme == .dark ? 0.02 : 0.10
    }

    private var midBackgroundOpacity: Double {
        colorScheme == .dark ? 0.42 : 0.62
    }

    private var selectedTintOpacity: Double {
        colorScheme == .dark ? 0.11 : 0.07
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .trailing) {
                if hasImage {
                    SpotRowBackdropImageView(spot: spot)
                        .frame(
                            width: max(geo.size.width * (isSelected ? 0.6 : 0.55), 188),
                            height: geo.size.height
                        )
                        .clipped()
                        .opacity(imageOpacity)
                        .saturation(colorScheme == .dark ? (isSelected ? 1.16 : 1.1) : (isSelected ? 1.1 : 1.05))
                        .contrast(colorScheme == .dark ? 1.05 : 1.12)
                        .offset(x: 10)
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .white.opacity(0.18), location: 0.12),
                                    .init(color: .white.opacity(0.50), location: 0.36),
                                    .init(color: .white, location: 0.76)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    LinearGradient(
                        colors: [
                            Color(uiColor: .systemBackground),
                            Color(uiColor: .systemBackground).opacity(midBackgroundOpacity),
                            Color(uiColor: .systemBackground).opacity(trailingBackgroundOpacity)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
                if isSelected { Color.indigo.opacity(selectedTintOpacity) }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 絞り込みパネル（近くのスポットモード専用）

private struct SpotFilterPanel: View {
    let store: SpotListStore
    let onDismiss: () -> Void

    @State private var expandedKeys: Set<String> = []
    @Environment(\.colorScheme) private var colorScheme

    private var panelOverlayColor: Color {
        colorScheme == .dark
            ? Color(.secondarySystemBackground).opacity(0.94)
            : Color.white.opacity(0.55)
    }

    private var panelBorderGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color.white.opacity(0.18),
                    Color.white.opacity(0.06)
                ]
                : [
                    Color.white.opacity(0.9),
                    Color.white.opacity(0.4)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var expandedCourseBackground: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.045)
            : Color.primary.opacity(0.03)
    }

    private var panelShadowColor: Color {
        colorScheme == .dark ? .black.opacity(0.45) : .black.opacity(0.22)
    }

    private var sections: [(key: String, category: CourseCategory?, courses: [Course])] {
        var categoryOf: [String: CourseCategory?] = [:]
        var coursesByKey: [String: [Course]] = [:]
        for course in store.relevantCourses {
            let cat = course.categories.first
            let key = cat?.rawValue ?? "__other__"
            categoryOf[key] = cat
            coursesByKey[key, default: []].append(course)
        }
        var result: [(String, CourseCategory?, [Course])] = []
        for cat in CourseCategory.allCases {
            if let cs = coursesByKey[cat.rawValue] { result.append((cat.rawValue, cat, cs)) }
        }
        if let cs = coursesByKey["__other__"] { result.append(("__other__", nil, cs)) }
        return result
    }

    private func categoryState(courses: [Course]) -> Bool? {
        let excludedCount = courses.filter { store.excludedCourseIds.contains($0.id) }.count
        if excludedCount == 0 { return true }
        if excludedCount == courses.count { return false }
        return nil
    }

    private func toggleCategory(courses: [Course]) {
        let state = categoryState(courses: courses)
        for c in courses {
            if state == true { store.excludedCourseIds.insert(c.id) }
            else { store.excludedCourseIds.remove(c.id) }
        }
        store.recalculateNearbySpots()
    }

    private func toggleCourse(_ course: Course) {
        if store.excludedCourseIds.contains(course.id) { store.excludedCourseIds.remove(course.id) }
        else { store.excludedCourseIds.insert(course.id) }
        store.recalculateNearbySpots()
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in if value.translation.height > 30 { onDismiss() } }
                )

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("絞り込み", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 3) {
                        Text("対象スポット数")
                        Text("\(store.totalFilteredSpotCount)件")
                            .monospacedDigit()
                            .foregroundStyle(.indigo)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Button("完了", action: onDismiss)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.indigo)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            Divider()

            HStack {
                Text("コースで絞り込む")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 4)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(sections, id: \.key) { section in
                        HStack(spacing: 12) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) { toggleCategory(courses: section.courses) }
                            } label: {
                                checkboxIcon(state: categoryState(courses: section.courses))
                            }
                            .buttonStyle(.plain)

                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if expandedKeys.contains(section.key) { expandedKeys.remove(section.key) }
                                    else { expandedKeys.insert(section.key) }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    if let cat = section.category {
                                        Image(systemName: cat.iconName).font(.subheadline).foregroundStyle(.indigo).frame(width: 20)
                                    } else {
                                        Image(systemName: "airplane").font(.subheadline).foregroundStyle(.secondary).frame(width: 20)
                                    }
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(section.category?.displayName ?? "その他")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Text("(\(section.courses.flatMap(\.spots).count)スポット)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: expandedKeys.contains(section.key) ? "chevron.up" : "chevron.down")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        if expandedKeys.contains(section.key) {
                            ForEach(section.courses) { course in
                                HStack(spacing: 12) {
                                    Color.clear.frame(width: 24)
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.15)) { toggleCourse(course) }
                                    } label: {
                                        checkboxIcon(state: !store.excludedCourseIds.contains(course.id))
                                    }
                                    .buttonStyle(.plain)

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(course.title)
                                            .font(.subheadline)
                                            .foregroundStyle(store.excludedCourseIds.contains(course.id) ? Color.secondary : Color.primary)
                                            .lineLimit(2)
                                        Text("(\(course.spots.count)スポット)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(expandedCourseBackground)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        Divider()
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(colorScheme == .dark ? .regularMaterial : .ultraThinMaterial)
                .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).fill(panelOverlayColor) }
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            panelBorderGradient,
                            lineWidth: 0.8
                        )
                }
        }
        .shadow(color: panelShadowColor, radius: 28, x: 0, y: -8)
        .ignoresSafeArea(edges: .bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func checkboxIcon(state: Bool?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(
                    state == true ? Color.indigo
                    : state == nil ? Color.indigo.opacity(0.22)
                    : Color.clear
                )
                .frame(width: 20, height: 20)
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(
                    state == false ? Color.secondary.opacity(0.4) : Color.indigo,
                    lineWidth: 1.5
                )
                .frame(width: 20, height: 20)
            if state == true {
                Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
            } else if state == nil {
                Rectangle().fill(Color.indigo).frame(width: 10, height: 2)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: state)
    }
}

// MARK: - コース詳細ナビゲーションルート

private struct CourseRoute: Identifiable, Hashable {
    let course: Course
    let initialSpotId: UUID?
    var id: UUID { course.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

// MARK: - スポット行背景画像ビュー

private struct SpotRowBackdropImageView: View {
    let spot: CourseSpot

    var body: some View {
        Group {
            if let uiImage = spot.localCoverImagePath.flatMap({ LocalImageStorage.shared.load(from: $0) }) {
                Image(uiImage: uiImage).resizable().scaledToFill()
            } else if let urlStr = spot.coverImageUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default: Color.clear
                    }
                }
            } else {
                Color.clear
            }
        }
    }
}
