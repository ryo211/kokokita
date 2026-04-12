import SwiftUI
import MapKit
import PhotosUI
import CoreLocation

/// スポット作成・編集シート
/// - 地図上部固定（タップ・検索・"この場所を選択"で場所設定）
/// - 周辺POIカルーセル
/// - 名前入力（必須）
/// - 詳細設定（説明・画像・半径）は歯車ボタンから別シート
struct SpotEditorSheet: View {

    // MARK: - 初期化

    enum Mode {
        case create
        case edit(spot: EditingSpot)
    }

    private let mode: Mode
    private let onSave: (EditingSpot) -> Void

    init(mode: Mode, onSave: @escaping (EditingSpot) -> Void) {
        self.mode = mode
        self.onSave = onSave
    }

    // MARK: - 位置情報

    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var address: String?

    // 地図
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    @State private var mapCenterCoordinate = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)

    // 近くのPOI
    @State private var nearbyPOIs: [MKMapItem] = []
    @State private var isLoadingPOI = false

    // MARK: - スポット基本情報（必須）

    @State private var name: String = ""

    // MARK: - オプション

    @State private var spotDescription: String = ""
    @State private var spotImage: UIImage?
    @State private var imagePickerItem: PhotosPickerItem?
    /// 達成判定半径（新規作成時はデフォルト150m）
    @State private var customRadius: Double = 150

    // MARK: - UI 状態

    @Environment(\.dismiss) private var dismiss
    /// インライン検索モード中か
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearchLoading = false
    @FocusState private var searchFocused: Bool

    @State private var showPhotoImport = false
    @State private var showCoordinateInput = false
    @State private var showOptionalFields = false
    /// 写真取り込み用ダミータイムスタンプ（PhotoImportSheet の型要件を満たすため）
    @State private var dummyTimestamp: Date = Date()

    // MARK: - Computed

    private var hasValidLocation: Bool {
        guard let lat = latitude, let lon = longitude else { return false }
        return !(lat == 0 && lon == 0)
    }

    private var canSave: Bool {
        !name.isEmpty && hasValidLocation
    }

    private var navigationTitle: String {
        switch mode {
        case .create: return L.SpotEditor.createTitle
        case .edit:   return L.SpotEditor.editTitle
        }
    }

    private var saveButtonTitle: String {
        switch mode {
        case .create: return L.SpotEditor.addButton
        case .edit:   return L.SpotEditor.saveButton
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    // 通常モード：地図 + 下エリア
                    VStack(spacing: 0) {
                        mapArea
                            .frame(height: geo.size.height * 0.50)
                        Divider()
                        bottomArea
                    }
                    // 検索モード：全画面オーバーレイ
                    if isSearching {
                        searchOverlay
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: isSearching)
            }
            .navigationTitle(isSearching ? "" : navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isSearching {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(L.Common.cancel) { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(saveButtonTitle) { commitSave() }
                            .fontWeight(.semibold)
                            .disabled(!canSave)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .task { loadInitialData() }
        .onChange(of: imagePickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    spotImage = img
                }
            }
        }
        .sheet(isPresented: $showPhotoImport) {
            PhotoImportSheet(
                latitude: $latitude,
                longitude: $longitude,
                addressLine: $address,
                timestamp: $dummyTimestamp
            ) { _ in }
        }
        .sheet(isPresented: $showCoordinateInput) {
            CoordinateInputSheet { lat, lon in
                let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                latitude = lat
                longitude = lon
                address = nil
                withAnimation {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))
                }
                Task {
                    await reverseGeocode(coordinate: coord)
                    await searchNearbyPOI(at: coord)
                }
            }
        }
    }

    // MARK: - 地図エリア

    private var mapArea: some View {
        ZStack(alignment: .top) {
            // 地図本体
            Map(position: $cameraPosition) {
                if hasValidLocation, let lat = latitude, let lon = longitude {
                    let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)

                    // 達成判定半径の可視化
                    MapCircle(center: coord, radius: customRadius)
                        .foregroundStyle(.indigo.opacity(0.12))
                        .stroke(.indigo.opacity(0.5), lineWidth: 1.5)

                    Annotation("", coordinate: coord, anchor: .bottom) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.indigo)
                            .shadow(radius: 4)
                    }
                }
            }
            .mapStyle(.standard(emphasis: .muted))
            .mapControls {
                MapCompass()
            }
            .onMapCameraChange { ctx in
                mapCenterCoordinate = ctx.region.center
            }
            .overlay(alignment: .center) {
                // 地図中心を示す照準（常時表示）
                // 「この場所を選択」の対象がどこかをユーザーに示す
                ZStack {
                    // 横線
                    Rectangle()
                        .fill(Color.indigo.opacity(0.6))
                        .frame(width: 18, height: 1.5)
                    // 縦線
                    Rectangle()
                        .fill(Color.indigo.opacity(0.6))
                        .frame(width: 1.5, height: 18)
                    // 中心点
                    Circle()
                        .fill(Color.indigo.opacity(0.8))
                        .frame(width: 4, height: 4)
                }
                .allowsHitTesting(false)
            }

            // 上部オーバーレイ：検索バー + 写真ボタン
            HStack(spacing: 8) {
                // 検索バー（タップで検索モードへ）
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isSearching = true
                    }
                    searchFocused = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(L.SpotEditor.searchPlaceholder)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)

                // 取り込みメニュー（写真 / 緯度経度入力）
                Menu {
                    Button {
                        showPhotoImport = true
                    } label: {
                        Label(L.SpotEditor.importFromPhoto, systemImage: "photo.on.rectangle")
                    }
                    Button {
                        showCoordinateInput = true
                    } label: {
                        Label(L.SpotEditor.enterCoordinates, systemImage: "location.circle")
                    }
                } label: {
                    Image(systemName: "arrow.down.to.line.circle.fill")
                        .font(.system(size: 22, weight: .medium))
                        .frame(width: 38, height: 38)
                        .background(.regularMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)

            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            // 下部オーバーレイ：場所情報 + "この場所を選択"ボタン
            VStack(spacing: 0) {
                Spacer()
                HStack(alignment: .bottom) {
                    // 場所情報バッジ（左下〜中央下）：常時表示、未選択時はガイドメッセージ
                    Group {
                        if hasValidLocation {
                            locationInfoBadge
                        } else {
                            // 未選択時のガイドメッセージ（インジゴでハイライト）
                            HStack(spacing: 5) {
                                Image(systemName: "mappin.slash")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.indigo)
                                Text(L.SpotEditor.noLocationSelected)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.indigo)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.indigo.opacity(0.4), lineWidth: 1)
                            )
                            .shadow(color: .indigo.opacity(0.15), radius: 6, x: 0, y: 2)
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hasValidLocation)

                    Spacer()

                    // "この場所を選択" ボタン（右下）
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
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
    }

    /// 場所情報バッジ（glassmorphism スタイル）
    private var locationInfoBadge: some View {
        HStack(alignment: .top, spacing: 6) {
            VStack(alignment: .leading, spacing: 3) {
                if let addr = address, !addr.isEmpty {
                    Text(addr)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
                if let lat = latitude, let lon = longitude {
                    Text(String(format: "%.5f, %.5f", lat, lon))
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            // ✕ で位置設定を解除
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .onTapGesture { clearLocation() }
        }
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

    private func clearLocation() {
        latitude = nil
        longitude = nil
        address = nil
        nearbyPOIs = []
    }

    // MARK: - 下エリア

    private var bottomArea: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 近くの場所カルーセル
                if hasValidLocation {
                    nearbyPOISection
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Divider()
                }

                // スポット画像アイコン + 名前入力（横並び）
                // スポット名エリア（必須：未入力時にインジゴ枠でハイライト）
                HStack(alignment: .top, spacing: 12) {
                    // スポット画像（SNSアイコン風）
                    // 画像なし: PhotosPicker + 鉛筆バッジ
                    // 画像あり: PhotosPicker + ばつボタン（削除）
                    ZStack(alignment: .bottomTrailing) {
                        PhotosPicker(selection: $imagePickerItem, matching: .images) {
                            ZStack {
                                if let img = spotImage {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color(.systemGray5))
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color(.systemGray4), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)

                        if spotImage == nil {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white, Color.indigo)
                                .offset(x: 5, y: 5)
                                .allowsHitTesting(false)
                        } else {
                            Button {
                                spotImage = nil
                                imagePickerItem = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white, Color(.systemGray2))
                                    .offset(x: 5, y: 5)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // スポット名
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L.SpotEditor.nameLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(name.isEmpty ? Color.indigo : .secondary)
                            .padding(.top, 4)
                        TextField(L.SpotEditor.namePlaceholder, text: $name)
                            .font(.body)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(name.isEmpty ? Color.indigo.opacity(0.5) : Color.clear, lineWidth: 1.5)
                )
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(name.isEmpty ? Color.indigo.opacity(0.04) : Color.clear)
                )
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .animation(.easeInOut(duration: 0.2), value: name.isEmpty)

                Divider().padding(.horizontal, 16).padding(.top, 4)

                // オプション項目（説明文・達成判定半径）折りたたみ
                VStack(spacing: 0) {
                    // 展開トグルボタン
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showOptionalFields.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(showOptionalFields ? L.Common.hideOptions : L.Common.showOptions)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.indigo)
                            Image(systemName: showOptionalFields ? "chevron.up" : "chevron.down")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.indigo)
                        }
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)

                    if showOptionalFields {
                        Divider().padding(.horizontal, 16)

                        // 説明文
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L.SpotEditor.descriptionLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.top, 12)
                            TextField(L.SpotEditor.descriptionPlaceholder, text: $spotDescription, axis: .vertical)
                                .font(.body)
                                .lineLimit(2...4)
                                .padding(.bottom, 10)
                        }
                        .padding(.horizontal, 16)

                        Divider().padding(.horizontal, 16)

                        // 達成判定半径スライダー
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(L.SpotEditor.recognitionRadius)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(customRadius))m")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            Slider(value: $customRadius, in: 50...1000, step: 10)
                                .tint(.indigo)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: hasValidLocation)
    }

    private var nearbyPOISection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isLoadingPOI {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7)
                    Text(L.Confirmation.loadingPOI)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            } else if !nearbyPOIs.isEmpty {
                Text(L.SpotEditor.nearbyPlaces)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(nearbyPOIs.prefix(8), id: \.self) { item in
                            Button { selectNearbyPOI(item) } label: {
                                poiChip(for: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                }
            }
        }
    }

    private func poiChip(for item: MKMapItem) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(.indigo)
                .font(.caption)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name ?? "")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let cat = item.pointOfInterestCategory?.localizedName {
                    Text(cat)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .clipShape(Capsule())
    }

    // MARK: - 検索モード（インライン）

    /// Google Maps 風インライン検索オーバーレイ
    private var searchOverlay: some View {
        VStack(spacing: 0) {
            // 検索バー（アクティブ）
            HStack(spacing: 10) {
                // ＜ ボタン：戻る
                Button { exitSearch() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

                // TextField + ✕ボタンを ZStack で重ねて UITextField の境界外に確実に配置
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

                    // ✕：UITextField のフレーム外に配置することで、
                    // 確定済みテキストの状態でも確実にタップを受け取る
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
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(searchResults, id: \.self) { item in
                            Button {
                                selectSearchResult(item)
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
            }
        }
        .background(Color(.systemBackground))
    }

    private func exitSearch() {
        searchFocused = false
        withAnimation(.easeInOut(duration: 0.25)) {
            isSearching = false
        }
        searchText = ""
        searchResults = []
    }

    private func performSearch(query: String) async {
        isSearchLoading = true
        defer { isSearchLoading = false }
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = query
        if let res = try? await MKLocalSearch(request: req).start() {
            searchResults = res.mapItems
        } else {
            searchResults = []
        }
    }

    private func selectSearchResult(_ item: MKMapItem) {
        let coord = item.placemark.coordinate
        exitSearch()
        setLocation(
            coordinate: coord,
            address: formatAddress(item.placemark),
            name: item.name
        )
        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
    }

    // MARK: - 場所選択アクション

    /// 地図中心を場所として選択し、逆ジオコーディング + 周辺POI検索
    private func selectMapCenter() {
        let coord = mapCenterCoordinate
        latitude = coord.latitude
        longitude = coord.longitude
        address = nil

        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }

        Task {
            await reverseGeocode(coordinate: coord)
            await searchNearbyPOI(at: coord)
        }
    }

    private func setLocation(coordinate: CLLocationCoordinate2D, address: String?, name: String?) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
        self.address = address

        // 場所名で常に上書き
        if let n = name, !n.isEmpty {
            self.name = n
        }

        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }

        if address == nil {
            Task { await reverseGeocode(coordinate: coordinate) }
        }
        Task { await searchNearbyPOI(at: coordinate) }
    }

    private func selectNearbyPOI(_ item: MKMapItem) {
        let coord = item.placemark.coordinate
        latitude = coord.latitude
        longitude = coord.longitude
        // 選択した場所名で常に上書き
        if let n = item.name, !n.isEmpty { name = n }
        address = formatAddress(item.placemark)

        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            ))
        }
    }

    // MARK: - 逆ジオコーディング / POI検索

    private func reverseGeocode(coordinate: CLLocationCoordinate2D) async {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        if let pm = try? await geocoder.reverseGeocodeLocation(location).first {
            address = formatPlacemark(pm)
        }
    }

    private func searchNearbyPOI(at coordinate: CLLocationCoordinate2D) async {
        isLoadingPOI = true
        defer { isLoadingPOI = false }
        let req = MKLocalPointsOfInterestRequest(center: coordinate, radius: AppConfig.poiSearchRadius)
        req.pointOfInterestFilter = MKPointOfInterestFilter(including: [
            .restaurant, .cafe, .bakery,
            .museum, .park, .nationalPark, .beach,
            .store, .hotel, .publicTransport, .airport, .hospital
        ])
        if let response = try? await MKLocalSearch(request: req).start() {
            nearbyPOIs = response.mapItems
        } else {
            nearbyPOIs = []
        }
    }

    // MARK: - 初期データ読み込み

    private func loadInitialData() {
        guard case .edit(let spot) = mode else { return }
        name = spot.name
        spotDescription = spot.spotDescription ?? ""
        address = spot.address
        latitude = spot.latitude
        longitude = spot.longitude
        spotImage = spot.coverImage
        customRadius = spot.customRadius
        // 説明文や非デフォルト半径がある場合は詳細設定を自動展開
        if !(spot.spotDescription ?? "").isEmpty || spot.customRadius != 150 {
            showOptionalFields = true
        }

        if let lat = spot.latitude, let lon = spot.longitude {
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            cameraPosition = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
            mapCenterCoordinate = coord
            Task { await searchNearbyPOI(at: coord) }
        }
    }

    // MARK: - 保存

    private func commitSave() {
        let existingId: UUID?
        let existingPath: String?
        let existingUrl: String?

        switch mode {
        case .create:
            existingId = nil; existingPath = nil; existingUrl = nil
        case .edit(let spot):
            existingId = spot.existingId
            existingPath = spot.localCoverImagePath
            existingUrl = spot.coverImageUrl
        }

        var result = EditingSpot(
            id: existingId ?? UUID(),
            existingId: existingId,
            name: name,
            address: address?.isEmpty == false ? address : nil,
            latitude: latitude,
            longitude: longitude,
            spotDescription: spotDescription.isEmpty ? nil : spotDescription,
            coverImage: spotImage,
            localCoverImagePath: existingPath,
            coverImageUrl: existingUrl,
            useCustomRadius: true,
            customRadius: customRadius
        )
        if existingId == nil { result.existingId = result.id }
        onSave(result)
        dismiss()
    }

    // MARK: - Helpers

    private func formatAddress(_ placemark: MKPlacemark) -> String? {
        [placemark.administrativeArea, placemark.locality,
         placemark.subLocality, placemark.thoroughfare]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined()
            .nilIfEmpty()
    }

    private func formatPlacemark(_ pm: CLPlacemark) -> String? {
        [pm.administrativeArea, pm.locality, pm.subLocality, pm.thoroughfare]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined()
            .nilIfEmpty()
    }
}

// MARK: - 座標入力シート

/// 緯度・経度を手動入力して場所を設定する
private struct CoordinateInputSheet: View {
    let onConfirm: (Double, Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var latText = ""
    @State private var lonText = ""

    private var parsedLat: Double? {
        Double(latText.replacingOccurrences(of: "，", with: ".").replacingOccurrences(of: ",", with: "."))
    }
    private var parsedLon: Double? {
        Double(lonText.replacingOccurrences(of: "，", with: ".").replacingOccurrences(of: ",", with: "."))
    }
    private var isValid: Bool {
        guard let lat = parsedLat, let lon = parsedLon else { return false }
        return lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L.SpotEditor.latitude) {
                    TextField("35.68123", text: $latText)
                        .keyboardType(.numbersAndPunctuation)
                }
                Section(L.SpotEditor.longitude) {
                    TextField("139.76712", text: $lonText)
                        .keyboardType(.numbersAndPunctuation)
                }
            }
            .navigationTitle(L.SpotEditor.coordinateInputTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L.Common.cancel) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L.Common.done) {
                        if let lat = parsedLat, let lon = parsedLon {
                            onConfirm(lat, lon)
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

