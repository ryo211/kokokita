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
// 地図上の任意地点（デフォルト: 現在地）から近い順の巡礼スポットを表示する
struct SpotListScreen: View {
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

    @Environment(\.spotFavoriteStore) private var favoriteStore

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack(alignment: .top) {
                    VStack(spacing: 0) {
                        // 地図（mapOnly: 全画面 / split: 50% / listOnly: 非表示）
                        if viewLayout == .mapOnly {
                            mapSection
                        } else if viewLayout == .split {
                            mapSection
                                .frame(height: geo.size.height * 0.5)
                        }

                        // レイアウト切替バー（常時表示）
                        layoutStrip

                        Divider()

                        // 一覧（mapOnly: 非表示 / split・listOnly: 表示）
                        if viewLayout != .mapOnly {
                            spotListSection
                        }
                    }

                    // 検索オーバーレイ（検索中のみ表示）
                    if isSearching {
                        searchOverlay
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: isSearching)
                .animation(.easeInOut(duration: 0.3), value: viewLayout)
            }
            .task {
                store.favoriteSpotIds = favoriteStore.favoriteSpotIds
                await store.load()
                initializeCamera()
            }
            // お気に入り変更をストアに反映
            .onChange(of: favoriteStore.favoriteSpotIds) { _, ids in
                store.favoriteSpotIds = ids
                if store.favoritesOnly { store.recalculateNearbySpots() }
            }
            .navigationDestination(item: $courseDetailRoute) { route in
                CourseDetailView(course: route.course, initialSelectedSpotId: route.initialSpotId)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - 地図セクション

    private var mapSection: some View {
        ZStack(alignment: .top) {
            Map(position: $cameraPosition, interactionModes: [.pan, .zoom, .pitch]) {
                // スポットピン（近い順に番号付き）
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
                                isSelected: selectedSpotId == item.spot.id
                            )
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedSpotId = selectedSpotId == item.spot.id ? nil : item.spot.id
                                }
                                fitAllPoints()
                            }
                        }

                        // 選択中スポットの認識範囲サークル
                        if selectedSpotId == item.spot.id {
                            MapCircle(
                                center: coord,
                                radius: item.spot.recognitionRadiusMeters ?? item.course.recognitionRadiusMeters
                            )
                            .foregroundStyle(Color.indigo.opacity(0.08))
                            .stroke(Color.indigo.opacity(0.5), lineWidth: 1.5)
                        }
                    }
                }

                // 確定済み選択地点ピン
                if let coord = store.selectedCoordinate {
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
            // 地図のスクロール・ズームに合わせて中心座標を追跡
            .onMapCameraChange { ctx in
                mapCenterCoordinate = ctx.region.center
            }
            // 照準（地図中心＝「この場所を選択」の対象を示す）
            .overlay(alignment: .center) {
                crosshairView
            }
            // 「この場所を選択」ボタン（右下）
            .overlay(alignment: .bottomTrailing) {
                selectLocationButton
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }

        }
    }

    // 確定済み選択地点ピン（スポット追加画面と同じデザイン）
    private var selectedPinView: some View {
        Image(systemName: "mappin")
            .font(.system(size: 32))
            .foregroundStyle(.indigo)
            .shadow(radius: 4)
    }

    // 照準（常時表示・「この場所を選択」の対象を示す）
    private var crosshairView: some View {
        ZStack {
            Rectangle()
                .fill(Color.indigo.opacity(0.6))
                .frame(width: 18, height: 1.5)
            Rectangle()
                .fill(Color.indigo.opacity(0.6))
                .frame(width: 1.5, height: 18)
            Circle()
                .fill(Color.indigo.opacity(0.8))
                .frame(width: 4, height: 4)
        }
        .allowsHitTesting(false)
    }

    // 住所カード（左下・緯度経度なし）
    private func addressCard(_ address: String) -> some View {
        Text(address)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.primary)
            .lineLimit(2)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 2)
            .frame(maxWidth: 220, alignment: .leading)
    }

    // 右下ボタン群（現在地 + この場所を選択）
    private var selectLocationButton: some View {
        HStack(spacing: 8) {
            // 現在地ボタン
            Button {
                moveToCurrentLocation()
            } label: {
                Image(systemName: "location.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.indigo)
                    .padding(8)
                    .background(.regularMaterial, in: Circle())
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            // この場所を選択ボタン
            Button {
                selectMapCenter()
            } label: {
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

    // 表示件数ドロップダウンボタン（レイアウトバー右）
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

    // MARK: - スポット一覧セクション

    private var spotListSection: some View {
        ZStack(alignment: .bottom) {
            // スポット一覧本体
            Group {
                if store.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                                        distance: item.distance,
                                        onCourseTap: { courseDetailRoute = CourseRoute(course: item.course, initialSpotId: item.spot.id) }
                                    )
                                    .id(item.spot.id)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedSpotId = selectedSpotId == item.spot.id ? nil : item.spot.id
                                        }
                                        fitAllPoints()
                                    }
                                    if index < store.nearbySpots.count - 1 {
                                        Divider()
                                            .padding(.leading, 60)
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

            // 絞り込みボタン（右下固定）
            if !showFilter {
                HStack {
                    Spacer()
                    filterButton
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                }
            }

            // 絞り込みパネル（下からスライドイン）
            if showFilter {
                SpotFilterPanel(store: store) {
                    withAnimation(.spring(duration: 0.35, bounce: 0.05)) {
                        showFilter = false
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.05), value: showFilter)
        .clipped()
    }

    private var filterButton: some View {
        Button {
            withAnimation(.spring(duration: 0.35, bounce: 0.05)) {
                showFilter = true
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.indigo, in: Circle())
                .shadow(color: Color.indigo.opacity(0.45), radius: 8, x: 0, y: 4)
                .overlay(alignment: .topTrailing) {
                    // フィルター適用中バッジ
                    if !store.excludedCourseIds.isEmpty {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 10, height: 10)
                            .overlay {
                                Circle().fill(Color.indigo.opacity(0.7))
                                    .frame(width: 7, height: 7)
                            }
                            .offset(x: 2, y: -2)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // 空状態ビュー
    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(store.selectedCoordinate == nil
                 ? L.SpotList.locationUnavailable
                 : L.SpotList.noSpots)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - 検索オーバーレイ

    private var searchOverlay: some View {
        VStack(spacing: 0) {
            // アクティブ検索バー
            HStack(spacing: 10) {
                Button {
                    exitSearch()
                } label: {
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
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))

            Divider()

            // 検索結果 or ローディング
            if isSearchLoading {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.8)
                    Text(L.Common.loading)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(searchResults, id: \.self) { item in
                            Button {
                                selectFromSearch(item)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "mappin.circle")
                                        .foregroundStyle(.indigo)
                                        .font(.title3)
                                        .frame(width: 32)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name ?? "")
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                        if let addr = item.placemark.thoroughfare {
                                            Text(addr)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
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
            // 虫眼鏡アイコン（タップで検索モードへ）
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isSearching = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    searchFocused = true
                }
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.indigo)
                    .frame(width: 32, height: 32)
                    .background(.regularMaterial, in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(Color.indigo.opacity(0.25), lineWidth: 0.8)
                    }
                    .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
            }
            .buttonStyle(.plain)

            // 選択地点の住所カード + "から近いスポット"
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
                // 住所が変わったらフェードで更新
                .id(selectedAddress ?? store.selectedLocationName ?? "")
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
                .animation(.easeInOut(duration: 0.25), value: selectedAddress)

                Text("から近いスポット")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }

            Spacer()

            // 右: 表示件数設定
            spotCountButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        // 上下スワイプでレイアウト切替
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

    /// isUp=true: 一覧拡大方向 / isUp=false: 地図拡大方向
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

    /// 現在地を選択地点として確定する
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

    /// 地図中心を選択地点として確定する
    private func selectMapCenter() {
        let coord = mapCenterCoordinate
        store.updateSelectedLocation(coord, name: nil)
        selectedAddress = nil
        fitAllPoints()
        Task { await reverseGeocode(coordinate: coord) }
    }

    /// 場所検索結果から地点を選択する（自動確定）
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

    /// 検索モードを終了する
    private func exitSearch() {
        searchFocused = false
        withAnimation(.easeInOut(duration: 0.25)) {
            isSearching = false
        }
        searchText = ""
        searchResults = []
    }

    /// MKLocalSearch で場所を検索する
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

    /// 起動時: カメラをフィットし、初期選択地点の住所を取得する
    private func initializeCamera() {
        fitAllPoints()
        if let coord = store.selectedCoordinate {
            Task { await reverseGeocode(coordinate: coord) }
        }
    }

    /// 逆ジオコーディングで住所を取得する
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
        if !result.isEmpty {
            selectedAddress = result
        }
    }

    /// 選択地点を中心に、全スポットが収まるようにズームを調整する
    private func fitAllPoints() {
        guard let center = store.selectedCoordinate else { return }

        // スポットがない場合はデフォルトスパンで選択地点を表示
        guard !store.nearbySpots.isEmpty else {
            withAnimation {
                cameraPosition = .region(MKCoordinateRegion(
                    center: center,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                ))
            }
            return
        }

        // 選択地点から各スポットまでの緯度・経度差の最大値を求める
        var maxLatDelta: CLLocationDegrees = 0.005
        var maxLonDelta: CLLocationDegrees = 0.005
        for item in store.nearbySpots where item.spot.hasValidCoordinate {
            maxLatDelta = max(maxLatDelta, abs(item.spot.latitude  - center.latitude))
            maxLonDelta = max(maxLonDelta, abs(item.spot.longitude - center.longitude))
        }

        // 選択地点を中心に、全スポットが余裕を持って収まるスパン（× 2.4）
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

// MARK: - スポットピンビュー（CourseDetailView と同じ実装）

private struct SpotPinView: View {
    let orderNumber: Int
    let isCheckedIn: Bool
    let isSelected: Bool

    private var pinColor: Color { isCheckedIn ? .indigo : Color(uiColor: .systemGray3) }
    private var size: CGFloat { isSelected ? 18 : 14 }

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.indigo : .white)
                .frame(width: size + 5, height: size + 5)
                .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
            Circle()
                .fill(pinColor)
                .frame(width: size, height: size)
            Text("\(orderNumber)")
                .font(.system(size: isSelected ? 8 : 6, weight: .bold))
                .foregroundStyle(.white)
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - スポット行ビュー（CourseDetailView と同じ作り・コース名付き）

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
            // メイン行
            HStack(spacing: 12) {
                // 番号バッジ（距離順の順位）
                ZStack {
                    Circle()
                        .fill(spot.isCheckedIn ? Color.indigo : Color(uiColor: .systemGray4))
                        .frame(width: 32, height: 32)
                    Text("\(orderNumber)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    // コース名（リンク）- スポット名の上に表示
                    Button(action: onCourseTap) {
                        HStack(spacing: 2) {
                            Text(course.title)
                                .font(.caption)
                                .lineLimit(1)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundStyle(.indigo)
                    }
                    .buttonStyle(.plain)

                    // スポット名・チェック済みアイコン
                    HStack(spacing: 6) {
                        Text(spot.name)
                            .font(.body)

                        if spot.isCheckedIn {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.body)
                                .foregroundStyle(Color.indigo)
                        }
                    }

                    // 選択地点からの距離
                    if let text = distanceText {
                        HStack(spacing: 2) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                            Text(text)
                                .font(.caption2.bold().monospacedDigit())
                        }
                        .foregroundStyle(.indigo)
                        .padding(.top, 1)
                    }
                }

                Spacer()

                // ハートボタン（お気に入り）
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

            // 展開詳細（選択時のみ）
            if isSelected {
                SpotRowExpandedView(spot: spot)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background {
            SpotRowBackdropView(spot: spot, isSelected: isSelected)
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - 展開詳細ビュー（住所・訪問日）

private struct SpotRowExpandedView: View {
    let spot: CourseSpot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let iconWidth: CGFloat = 14

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "mappin.circle")
                    .font(.caption)
                    .frame(width: iconWidth)
                Text(spot.address ?? L.Course.noAddress)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(spot.address != nil ? Color.secondary : Color.secondary.opacity(0.5))
            .padding(.leading, 60)
            .padding(.trailing, 16)

            if let date = spot.firstCheckedInAt {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "calendar.circle")
                        .font(.caption)
                        .frame(width: iconWidth)
                    Text(L.Course.visitedOn(date.formatted(date: .long, time: .omitted)))
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Color.indigo)
                .padding(.leading, 60)
                .padding(.trailing, 16)
            } else {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "calendar.circle")
                        .font(.caption)
                        .frame(width: iconWidth)
                    Text(L.Course.notVisited)
                        .font(.caption)
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

// MARK: - スポット行背景ビュー（CourseDetailView と同じ実装）

private struct SpotRowBackdropView: View {
    let spot: CourseSpot
    let isSelected: Bool

    private var hasImage: Bool {
        spot.localCoverImagePath != nil || spot.coverImageUrl != nil
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
                        .opacity(isSelected ? 0.62 : 0.50)
                        .saturation(isSelected ? 1.1 : 1.05)
                        .contrast(1.12)
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
                            Color(uiColor: .systemBackground).opacity(0.62),
                            Color(uiColor: .systemBackground).opacity(0.10)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }

                if isSelected {
                    Color.indigo.opacity(0.07)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 絞り込みパネル

private struct SpotFilterPanel: View {
    let store: SpotListStore
    let onDismiss: () -> Void

    @State private var expandedKeys: Set<String> = []
    @Environment(\.spotFavoriteStore) private var favoriteStore

    private let limitOptions = [10, 20, 30, 50]

    // カテゴリ別コース分類（first category で分類）
    private var sections: [(key: String, category: CourseCategory?, courses: [Course])] {
        var categoryOf: [String: CourseCategory?] = [:]
        var coursesByKey: [String: [Course]] = [:]
        for course in store.allCourses {
            let cat = course.categories.first
            let key = cat?.rawValue ?? "__other__"
            categoryOf[key] = cat
            coursesByKey[key, default: []].append(course)
        }
        var result: [(String, CourseCategory?, [Course])] = []
        for cat in CourseCategory.allCases {
            if let cs = coursesByKey[cat.rawValue] {
                result.append((cat.rawValue, cat, cs))
            }
        }
        if let cs = coursesByKey["__other__"] {
            result.append(("__other__", nil, cs))
        }
        return result
    }

    /// チェック状態: true=全選択 / nil=一部除外 / false=全除外
    private func categoryState(courses: [Course]) -> Bool? {
        let excludedCount = courses.filter { store.excludedCourseIds.contains($0.id) }.count
        if excludedCount == 0 { return true }
        if excludedCount == courses.count { return false }
        return nil
    }

    private func toggleCategory(courses: [Course]) {
        let state = categoryState(courses: courses)
        for c in courses {
            if state == true {
                store.excludedCourseIds.insert(c.id)
            } else {
                store.excludedCourseIds.remove(c.id)
            }
        }
        store.recalculateNearbySpots()
    }

    private func toggleCourse(_ course: Course) {
        if store.excludedCourseIds.contains(course.id) {
            store.excludedCourseIds.remove(course.id)
        } else {
            store.excludedCourseIds.insert(course.id)
        }
        store.recalculateNearbySpots()
    }

    var body: some View {
        VStack(spacing: 0) {
            // ドラッグハンドル（下スワイプで閉じる）
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            if value.translation.height > 30 { onDismiss() }
                        }
                )

            // タイトル行
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

            // コースで絞り込む ラベル
            HStack {
                Text("コースで絞り込む")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 4)

            // カテゴリ一覧
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(sections, id: \.key) { section in
                        // カテゴリ行
                        HStack(spacing: 12) {
                            // チェックボックス（独立ボタン）
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    toggleCategory(courses: section.courses)
                                }
                            } label: {
                                checkboxIcon(state: categoryState(courses: section.courses))
                            }
                            .buttonStyle(.plain)

                            // 展開ボタン（残り領域）
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if expandedKeys.contains(section.key) {
                                        expandedKeys.remove(section.key)
                                    } else {
                                        expandedKeys.insert(section.key)
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    if let cat = section.category {
                                        Image(systemName: cat.iconName)
                                            .font(.subheadline)
                                            .foregroundStyle(.indigo)
                                            .frame(width: 20)
                                    } else {
                                        Image(systemName: "folder")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 20)
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

                        // コース行（展開時のみ）
                        if expandedKeys.contains(section.key) {
                            ForEach(section.courses) { course in
                                HStack(spacing: 12) {
                                    Color.clear.frame(width: 24) // インデント
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            toggleCourse(course)
                                        }
                                    } label: {
                                        checkboxIcon(state: !store.excludedCourseIds.contains(course.id))
                                    }
                                    .buttonStyle(.plain)

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(course.title)
                                            .font(.subheadline)
                                            .foregroundStyle(
                                                store.excludedCourseIds.contains(course.id)
                                                    ? Color.secondary
                                                    : Color.primary
                                            )
                                            .lineLimit(2)
                                        Text("(\(course.spots.count)スポット)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.primary.opacity(0.03))
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
                .fill(.ultraThinMaterial)
                .overlay {
                    // 白みを強調するオーバーレイ
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.55))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.9), Color.white.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                }
        }
        .shadow(color: .black.opacity(0.22), radius: 28, x: 0, y: -8)
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
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            } else if state == nil {
                // 一部除外（インデタミネート）
                Rectangle()
                    .fill(Color.indigo)
                    .frame(width: 10, height: 2)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: state)
    }
}

// MARK: - コース詳細ナビゲーションルート

/// Course は Hashable でないため、id のみで同一性を判断するラッパー
private struct CourseRoute: Identifiable, Hashable {
    let course: Course
    /// 遷移先でフォーカスするスポットのID
    let initialSpotId: UUID?
    var id: UUID { course.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

// MARK: - スポット行背景画像ビュー（CourseDetailView と同じ実装）

private struct SpotRowBackdropImageView: View {
    let spot: CourseSpot

    var body: some View {
        Group {
            if let uiImage = spot.localCoverImagePath.flatMap({ LocalImageStorage.shared.load(from: $0) }) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let urlStr = spot.coverImageUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Color.clear
                    }
                }
            } else {
                Color.clear
            }
        }
    }
}
