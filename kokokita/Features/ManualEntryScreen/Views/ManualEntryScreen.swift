import SwiftUI
import PhotosUI
import MapKit

/// 後付け記録画面（2ステップ構成）。editingAggregate を渡すと編集モードで起動する。
struct ManualEntryScreen: View {
    private let editingAggregate: VisitAggregate?

    init(editingAggregate: VisitAggregate? = nil) {
        self.editingAggregate = editingAggregate
    }

    @Environment(\.dismiss) private var dismiss
    @State private var store = ManualEntryStore()

    // PhotosPicker用
    @State private var showCamera = false

    // 写真取り込みシート
    @State private var showPhotoImport = false

    // フルスクリーン写真表示
    @State private var fullScreenIndex: Int? = nil
    @State private var photoDragOffset: CGFloat = 0
    @State private var showManualEntryInfoSheet = false

    // MARK: - Step1 地図UI 状態
    @State private var mapCameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    )
    @State private var mapCenterCoordinate = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
    @State private var nearbyPOIs: [MKMapItem] = []
    @State private var isLoadingPOI = false
    @State private var isSearchingLocation = false
    @State private var locationSearchText = ""
    @State private var locationSearchResults: [MKMapItem] = []
    @State private var isLocationSearchLoading = false
    @State private var showCoordinateInput = false
    @FocusState private var locationSearchFocused: Bool

    // ラベル/グループ/メンバー候補
    @State private var labelOptions: [LabelTag] = []
    @State private var groupOptions: [GroupTag] = []
    @State private var memberOptions: [MemberTag] = []

    // ピッカー/作成シート
    @State private var labelPickerShown = false
    @State private var groupPickerShown = false
    @State private var memberPickerShown = false
    @State private var labelCreateShown = false
    @State private var groupCreateShown = false
    @State private var memberCreateShown = false

    // 作成入力
    @State private var newLabelName = ""
    @State private var newLabelColorId: String? = nil
    @State private var newGroupName = ""
    @State private var newMemberName = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                StepIndicator(currentStep: store.currentStep)
                    .padding(.top, 8)

                // ステップに応じたコンテンツ
                Group {
                    switch store.currentStep {
                    case .essentials:
                        step1Content
                    case .additionalInfo:
                        step2Content
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: store.currentStep == .essentials ? .leading : .trailing),
                    removal: .move(edge: store.currentStep == .essentials ? .trailing : .leading)
                ))
                .animation(.easeInOut(duration: 0.3), value: store.currentStep)
            }
            .navigationTitle(editingAggregate != nil ? L.ManualEntry.editTitle : L.ManualEntry.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .alert(item: alertBinding) { alertView(for: $0) }
            .sheet(isPresented: $showPhotoImport) { photoImportSheet }
            .sheet(isPresented: $showCamera) { cameraSheet }
            .sheet(isPresented: $showCoordinateInput) {
                ManualEntryCoordinateInputSheet { lat, lon in
                    let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    store.latitude = lat
                    store.longitude = lon
                    store.addressLine = nil
                    withAnimation {
                        mapCameraPosition = .region(MKCoordinateRegion(
                            center: coord,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        ))
                    }
                    Task {
                        await reverseGeocodeForStore(coordinate: coord)
                        await searchNearbyPOIForStore(at: coord)
                    }
                }
            }
            .sheet(isPresented: $showManualEntryInfoSheet) {
                ManualEntryInfoSheet()
                    .iPadSheetSize(iPhoneDetents: [.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .fullScreenCover(item: fullScreenBinding) { photoFullScreen(for: $0) }
            .task {
                if let agg = editingAggregate {
                    store.loadExisting(agg)
                    // 編集モード: 既存座標に地図を合わせる
                    if let lat = store.latitude, let lon = store.longitude {
                        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        mapCameraPosition = .region(MKCoordinateRegion(
                            center: coord,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        ))
                        mapCenterCoordinate = coord
                        await searchNearbyPOIForStore(at: coord)
                    }
                }
                await loadTaxonomyOptions()
            }
            // 写真取り込み等の外部変更で座標が更新された場合に地図を追従
            .onChange(of: store.latitude) { _, lat in
                guard let lat, let lon = store.longitude else { return }
                let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                withAnimation {
                    mapCameraPosition = .region(MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))
                }
                Task { await searchNearbyPOIForStore(at: coord) }
            }
            .safeAreaInset(edge: .bottom) {
                footerButtons
            }
        }
        .sheet(isPresented: $labelPickerShown) { labelPickerSheetContent }
        .sheet(isPresented: $groupPickerShown) { groupPickerSheetContent }
        .sheet(isPresented: $memberPickerShown) { memberPickerSheetContent }
    }

    // MARK: - Load Taxonomy Options

    private func loadTaxonomyOptions() async {
        labelOptions = ((try? AppContainer.shared.repo.allLabels()) ?? []).sortedByName
        groupOptions = ((try? AppContainer.shared.repo.allGroups()) ?? []).sortedByName
        memberOptions = ((try? AppContainer.shared.repo.allMembers()) ?? []).sortedByName
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(L.Common.cancel) { dismiss() }
        }
        ToolbarItem(placement: .principal) {
            HStack(spacing: 4) {
                RecordTypeIcon(isManualEntry: true, compact: true)
                Text(editingAggregate != nil ? L.ManualEntry.editTitle : L.ManualEntry.title)
                    .font(.headline)
                Button {
                    showManualEntryInfoSheet = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 2)
                .accessibilityLabel(L.ManualEntry.infoSheetTitle)
            }
        }
    }

    // MARK: - Step 1: 日時と場所（必須項目）

    private var step1Content: some View {
        GeometryReader { geo in
            ZStack {
                VStack(spacing: 0) {
                    step1MapArea
                        .frame(height: geo.size.height * 0.50)
                    Divider()
                    step1BottomArea
                }
                // インライン検索オーバーレイ
                if isSearchingLocation {
                    locationSearchOverlay
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isSearchingLocation)
        }
        // キーボード表示/非表示で地図高さが変わらないように固定
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - Step1 地図エリア

    private var step1MapArea: some View {
        ZStack(alignment: .top) {
            // 地図本体
            Map(position: $mapCameraPosition) {
                if store.hasValidLocation, let lat = store.latitude, let lon = store.longitude {
                    let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    Annotation("", coordinate: coord, anchor: .bottom) {
                        Image(systemName: "mappin")
                            .font(.system(size: 32))
                            .foregroundStyle(.orange)
                            .shadow(radius: 4)
                    }
                }
            }
            .mapStyle(.standard(emphasis: .muted))
            .mapControls { MapCompass() }
            .onMapCameraChange { ctx in
                mapCenterCoordinate = ctx.region.center
            }
            // 照準（常時表示）
            .overlay(alignment: .center) {
                ZStack {
                    Rectangle()
                        .fill(Color.orange.opacity(0.6))
                        .frame(width: 18, height: 1.5)
                    Rectangle()
                        .fill(Color.orange.opacity(0.6))
                        .frame(width: 1.5, height: 18)
                    Circle()
                        .fill(Color.orange.opacity(0.8))
                        .frame(width: 4, height: 4)
                }
                .allowsHitTesting(false)
            }

            // 上部: 検索バー + 位置取得導線
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { isSearchingLocation = true }
                    locationSearchFocused = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(L.ManualEntry.searchFieldPlaceholder)
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

                HStack(spacing: 8) {
                    Button {
                        showPhotoImport = true
                    } label: {
                        Label("写真から取り込み", systemImage: "photo.on.rectangle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.regularMaterial, in: Capsule())
                            .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)

                    Button {
                        showCoordinateInput = true
                    } label: {
                        Label("緯度経度を入力", systemImage: "location.circle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.regularMaterial, in: Capsule())
                            .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            // 下部: 場所バッジ + 「この場所を選択」ボタン
            VStack(spacing: 0) {
                Spacer()
                HStack(alignment: .bottom) {
                    // 場所バッジ（常時表示）
                    Group {
                        if store.hasValidLocation {
                            locationBadge
                        } else {
                            HStack(spacing: 5) {
                                Image(systemName: "mappin.slash")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.orange)
                                Text(L.ManualEntry.locationRequired)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.orange)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.orange.opacity(0.4), lineWidth: 1)
                            )
                            .shadow(color: .orange.opacity(0.15), radius: 6, x: 0, y: 2)
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: store.hasValidLocation)

                    Spacer()

                    // 「この場所を選択」ボタン
                    Button { selectMapCenterForStore() } label: {
                        Text(L.SpotEditor.selectLocation)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.orange, in: Capsule())
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
    }

    /// 場所選択済みバッジ
    private var locationBadge: some View {
        HStack(alignment: .top, spacing: 6) {
            VStack(alignment: .leading, spacing: 3) {
                if let addr = store.addressLine, !addr.isEmpty {
                    Text(addr)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
                if let lat = store.latitude, let lon = store.longitude {
                    Text(String(format: "%.5f, %.5f", lat, lon))
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
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

    // MARK: - Step1 下エリア

    private var step1BottomArea: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 近くの場所カルーセル
                if store.hasValidLocation {
                    step1POISection
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Divider().padding(.horizontal, 16)
                }

                // タイトル入力
                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                        .foregroundStyle(.orange)
                        .frame(width: 20)
                    TextField(L.VisitEdit.titlePlaceholder, text: $store.title)
                        .font(.body)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider().padding(.horizontal, 16)

                // 日時設定
                VStack(alignment: .leading, spacing: 0) {
                    // 写真取り込み済みの場合: 取り込んだ日時バッジを表示
                    if store.isPhotoImported {
                        HStack(spacing: 10) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.orange)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L.ManualEntry.importedFromPhotoLabel)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(store.timestampDisplay.formatted(.dateTime.year().month().day().hour().minute()))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                            }
                            Spacer()
                            Button {
                                store.isPhotoImported = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.orange.opacity(0.25), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // DatePicker（常時表示: 写真取り込み後も手動調整可）
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .foregroundStyle(.orange)
                            .frame(width: 20)
                        DatePicker(
                            L.ManualEntry.dateTime,
                            selection: $store.timestampDisplay,
                            in: ...Date(),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                    if !store.hasValidTimestamp {
                        Text(L.ManualEntry.futureDateNotAllowed)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.leading, 52)
                            .padding(.bottom, 8)
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.isPhotoImported)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.hasValidLocation)
    }

    private var step1POISection: some View {
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
                            Button { selectNearbyPOIForStore(item) } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundStyle(.orange)
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
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                }
            }
        }
    }

    // MARK: - 検索オーバーレイ

    private var locationSearchOverlay: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { exitLocationSearch() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

                ZStack(alignment: .trailing) {
                    TextField(L.ManualEntry.searchFieldPlaceholder, text: $locationSearchText)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .focused($locationSearchFocused)
                        .submitLabel(.search)
                        .padding(.trailing, locationSearchText.isEmpty ? 0 : 24)
                        .onSubmit {
                            let q = locationSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !q.isEmpty else { return }
                            Task { await performLocationSearch(query: q) }
                        }

                    if !locationSearchText.isEmpty {
                        Button {
                            locationSearchText = ""
                            locationSearchResults = []
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

            if isLocationSearchLoading {
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
                        ForEach(locationSearchResults, id: \.self) { item in
                            Button { selectLocationSearchResult(item) } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "mappin.circle")
                                        .foregroundStyle(.orange)
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

    // MARK: - Step1 アクション

    private func selectMapCenterForStore() {
        let coord = mapCenterCoordinate
        store.latitude = coord.latitude
        store.longitude = coord.longitude
        store.addressLine = nil
        withAnimation {
            mapCameraPosition = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
        Task {
            await reverseGeocodeForStore(coordinate: coord)
            await searchNearbyPOIForStore(at: coord)
        }
    }

    private func selectNearbyPOIForStore(_ item: MKMapItem) {
        let coord = item.placemark.coordinate
        store.latitude = coord.latitude
        store.longitude = coord.longitude
        if let n = item.name, !n.isEmpty { store.title = n }
        store.addressLine = formatAddressForStore(item.placemark)
        withAnimation {
            mapCameraPosition = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            ))
        }
    }

    private func clearLocation() {
        store.latitude = nil
        store.longitude = nil
        store.addressLine = nil
        nearbyPOIs = []
    }

    private func exitLocationSearch() {
        locationSearchFocused = false
        withAnimation(.easeInOut(duration: 0.25)) { isSearchingLocation = false }
        locationSearchText = ""
        locationSearchResults = []
    }

    private func selectLocationSearchResult(_ item: MKMapItem) {
        let coord = item.placemark.coordinate
        exitLocationSearch()
        store.latitude = coord.latitude
        store.longitude = coord.longitude
        store.title = item.name ?? ""
        store.addressLine = formatAddressForStore(item.placemark)
        withAnimation {
            mapCameraPosition = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
        Task { await searchNearbyPOIForStore(at: coord) }
    }

    private func performLocationSearch(query: String) async {
        isLocationSearchLoading = true
        defer { isLocationSearchLoading = false }
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = query
        if let res = try? await MKLocalSearch(request: req).start() {
            locationSearchResults = res.mapItems
        } else {
            locationSearchResults = []
        }
    }

    private func reverseGeocodeForStore(coordinate: CLLocationCoordinate2D) async {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        if let pm = try? await geocoder.reverseGeocodeLocation(location).first {
            store.addressLine = formatPlacemarkForStore(pm)
        }
    }

    private func searchNearbyPOIForStore(at coordinate: CLLocationCoordinate2D) async {
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

    private func formatAddressForStore(_ placemark: MKPlacemark) -> String? {
        [placemark.administrativeArea, placemark.locality,
         placemark.subLocality, placemark.thoroughfare]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined()
            .nilIfEmpty()
    }

    private func formatPlacemarkForStore(_ pm: CLPlacemark) -> String? {
        [pm.administrativeArea, pm.locality, pm.subLocality, pm.thoroughfare]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined()
            .nilIfEmpty()
    }

    // MARK: - Step 2: 付加情報

    private var step2Content: some View {
        Form {
            metadataSection
            taxonomySection
            photoSection
        }
    }

    private var metadataSection: some View {
        Section {
            TextField(L.VisitEdit.memoPlaceholder, text: $store.comment, axis: .vertical)
                .lineLimit(3...6)
        } header: {
            Text(L.VisitEdit.basicInfoSection)
        }
    }

    // MARK: - Taxonomy Section

    private var taxonomySection: some View {
        Section {
            // グループ
            groupRow

            // ラベル
            labelRow

            // メンバー
            memberRow
        } header: {
            Text(L.VisitEdit.taxonomySection)
        }
    }

    @ViewBuilder
    private var groupRow: some View {
        if store.groupId == nil {
            // 未選択時：選択ボタン + 追加ボタンを表示
            HStack(spacing: UIConstants.Spacing.medium) {
                Button { groupPickerShown = true } label: {
                    Label(L.VisitEdit.selectGroup, systemImage: "folder")
                        .foregroundStyle(ChipKind.defaultTint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    groupPickerShown = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(ChipKind.defaultTint)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
            }
        } else if let groupId = store.groupId, let name = groupOptions.first(where: { $0.id == groupId })?.name {
            // 選択済み時：フォルダ帰属表示 + 変更/削除ボタン
            HStack(alignment: .center, spacing: UIConstants.Spacing.medium) {
                Button { groupPickerShown = true } label: {
                    GroupBadge(name: name)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    store.groupId = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .imageScale(.medium)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var labelRow: some View {
        if store.labelIds.isEmpty {
            // 未選択時：選択ボタン + 追加ボタンを表示
            HStack(spacing: UIConstants.Spacing.medium) {
                Button { labelPickerShown = true } label: {
                    Label(L.VisitEdit.selectLabel, systemImage: "tag")
                        .foregroundStyle(ChipKind.defaultTint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    labelPickerShown = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(ChipKind.defaultTint)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
            }
        } else {
            // 選択済み時：アイコン + チップ + 追加ボタンを表示
            Button {
                labelPickerShown = true
            } label: {
                HStack(alignment: .center, spacing: UIConstants.Spacing.extraLarge) {
                    Image(systemName: "tag")
                        .foregroundStyle(ChipKind.defaultTint)
                        .imageScale(.medium)
                        .frame(height: 28, alignment: .center)

                    FlowRow(spacing: 12, rowSpacing: 6) {
                        ForEach(Array(store.labelIds), id: \.self) { labelId in
                            if let label = labelOptions.first(where: { $0.id == labelId }) {
                                Chip(label.name, kind: .label, size: .small, showRemoveButton: true, colorDot: LabelColorId.from(label.colorId)?.color) {
                                    store.labelIds.remove(labelId)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // 追加ボタン（右端に固定）
                    Button {
                        labelPickerShown = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(ChipKind.defaultTint)
                            .imageScale(.large)
                    }
                    .buttonStyle(.plain)
                    .frame(height: 28, alignment: .center)
                }
                .padding(.vertical, UIConstants.Spacing.extraSmall)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var memberRow: some View {
        if store.memberIds.isEmpty {
            // 未選択時：選択ボタン + 追加ボタンを表示
            HStack(spacing: UIConstants.Spacing.medium) {
                Button { memberPickerShown = true } label: {
                    Label(L.VisitEdit.selectMember, systemImage: "person")
                        .foregroundStyle(ChipKind.defaultTint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    memberPickerShown = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(ChipKind.defaultTint)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
            }
        } else {
            // 選択済み時：アイコン + チップ + 追加ボタンを表示
            Button {
                memberPickerShown = true
            } label: {
                HStack(alignment: .center, spacing: UIConstants.Spacing.extraLarge) {
                    Image(systemName: "person")
                        .foregroundStyle(ChipKind.defaultTint)
                        .imageScale(.medium)
                        .frame(height: 28, alignment: .center)

                    FlowRow(spacing: 12, rowSpacing: 6) {
                        ForEach(Array(store.memberIds), id: \.self) { memberId in
                            if let name = memberOptions.first(where: { $0.id == memberId })?.name {
                                Chip(name, kind: .member, size: .small, showRemoveButton: true) {
                                    store.memberIds.remove(memberId)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // 追加ボタン（右端に固定）
                    Button {
                        memberPickerShown = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(ChipKind.defaultTint)
                            .imageScale(.large)
                    }
                    .buttonStyle(.plain)
                    .frame(height: 28, alignment: .center)
                }
                .padding(.vertical, UIConstants.Spacing.extraSmall)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        Section {
            ManualEntryPhotoGridView(
                store: store,
                showCamera: $showCamera,
                fullScreenIndex: $fullScreenIndex
            )
        } header: {
            Text(L.Photo.photo)
        }
    }

    // MARK: - Footer Buttons

    private var footerButtons: some View {
        VStack(spacing: 12) {
            Divider()
            normalModeFooter
        }
        .background(.regularMaterial)
    }

    @ViewBuilder
    private var normalModeFooter: some View {
        switch store.currentStep {
        case .essentials:
            // ステップ1: 「次へ」と「このまま保存」
            HStack(spacing: 12) {
                // このまま保存
                Button {
                    if store.save() { dismiss() }
                } label: {
                    Text(L.ManualEntry.saveAndSkipDetails)
                        .font(.subheadline)
                        .foregroundStyle(store.canSave ? .orange : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(store.canSave ? Color.orange : Color.secondary, lineWidth: 1)
                        )
                }
                .disabled(!store.canSave)
                .buttonStyle(.plain)

                // 次へ
                Button {
                    withAnimation {
                        store.goToNextStep()
                    }
                } label: {
                    HStack {
                        Text(L.ManualEntry.next)
                            .font(.headline)
                        Image(systemName: "chevron.right")
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(store.canProceedToNextStep ? Color.orange : Color.secondary)
                    )
                }
                .disabled(!store.canProceedToNextStep)
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

        case .additionalInfo:
            // ステップ2: 「戻る」と「保存」
            HStack(spacing: 12) {
                // 戻る
                Button {
                    withAnimation {
                        store.goToPreviousStep()
                    }
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text(L.ManualEntry.back)
                            .font(.subheadline)
                    }
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.orange, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // 保存
                Button {
                    if store.save() { dismiss() }
                } label: {
                    Text(L.Common.save)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(store.canSave ? Color.orange : Color.secondary)
                        )
                }
                .disabled(!store.canSave)
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Alert

    private var alertBinding: Binding<AlertMsg?> {
        Binding(
            get: { store.alert.map { AlertMsg(id: UUID(), text: $0) } },
            set: { _ in store.alert = nil }
        )
    }

    private func alertView(for msg: AlertMsg) -> Alert {
        Alert(
            title: Text(L.Common.error),
            message: Text(msg.text),
            dismissButton: .default(Text(L.Common.ok))
        )
    }

    // MARK: - Sheets

    private var photoImportSheet: some View {
        PhotoImportSheet(
            latitude: $store.latitude,
            longitude: $store.longitude,
            addressLine: $store.addressLine,
            timestamp: $store.timestampDisplay,
            showsTimestamp: true,
            tintColor: .orange
        ) { image in
            store.addPhotos([image])
            store.isPhotoImported = true
        }
    }

    private var cameraSheet: some View {
        CameraPicker { image in
            store.addPhotos([image])
        }
        .ignoresSafeArea()
    }

    // MARK: - Full Screen Photo

    private var fullScreenBinding: Binding<PhotoPager.IndexWrapper?> {
        Binding(
            get: { fullScreenIndex.map { PhotoPager.IndexWrapper(index: $0) } },
            set: { fullScreenIndex = $0?.index }
        )
    }

    private func photoFullScreen(for wrapper: PhotoPager.IndexWrapper) -> some View {
        PhotoPager(
            paths: store.photoEffects.photoPathsEditing,
            startIndex: wrapper.index,
            externalDragOffset: $photoDragOffset
        )
    }

    // MARK: - Picker Sheet Contents

    @ViewBuilder
    private var labelPickerSheetContent: some View {
        LabelPickerSheet(
            selectedIds: $store.labelIds,
            labelOptions: $labelOptions,
            isPresented: $labelPickerShown,
            showCreateSheet: $labelCreateShown
        )
        .sheet(isPresented: $labelCreateShown) {
            LabelCreateSheet(
                newLabelName: $newLabelName,
                newLabelColorId: $newLabelColorId,
                isPresented: $labelCreateShown,
                onCreate: createLabelAndSelect
            )
        }
    }

    @ViewBuilder
    private var groupPickerSheetContent: some View {
        GroupPickerSheet(
            selectedId: $store.groupId,
            groupOptions: $groupOptions,
            isPresented: $groupPickerShown,
            showCreateSheet: $groupCreateShown
        )
        .sheet(isPresented: $groupCreateShown) {
            GroupCreateSheet(
                newGroupName: $newGroupName,
                isPresented: $groupCreateShown,
                onCreate: createGroupAndSelect
            )
        }
    }

    @ViewBuilder
    private var memberPickerSheetContent: some View {
        MemberPickerSheet(
            selectedIds: $store.memberIds,
            memberOptions: $memberOptions,
            isPresented: $memberPickerShown,
            showCreateSheet: $memberCreateShown
        )
        .sheet(isPresented: $memberCreateShown) {
            MemberCreateSheet(
                newMemberName: $newMemberName,
                isPresented: $memberCreateShown,
                onCreate: createMemberAndSelect
            )
        }
    }

    // MARK: - Create Actions

    private func createLabelAndSelect() {
        let name = newLabelName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let exist = labelOptions.first(where: { $0.name == name }) {
            store.labelIds.insert(exist.id)
        } else if let id = store.createLabel(name) {
            let tag = LabelTag(id: id, name: name, colorId: newLabelColorId)
            labelOptions.append(tag)
            store.labelIds.insert(id)
            // 色が設定されている場合は保存
            if let colorId = newLabelColorId {
                _ = try? AppContainer.shared.taxonomyRepo.updateLabelColor(id: id, colorId: colorId)
            }
        }
        newLabelName = ""
        newLabelColorId = nil
        labelCreateShown = false
    }

    private func createGroupAndSelect() {
        let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let exist = groupOptions.first(where: { $0.name == name }) {
            store.groupId = exist.id
        } else if let id = store.createGroup(name) {
            let tag = GroupTag(id: id, name: name)
            groupOptions.append(tag)
            store.groupId = id
        }
        newGroupName = ""
        groupCreateShown = false
    }

    private func createMemberAndSelect() {
        let name = newMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let exist = memberOptions.first(where: { $0.name == name }) {
            store.memberIds.insert(exist.id)
        } else if let id = store.createMember(name) {
            let tag = MemberTag(id: id, name: name)
            memberOptions.append(tag)
            store.memberIds.insert(id)
        }
        newMemberName = ""
        memberCreateShown = false
    }
}

// MARK: - Photo Grid

private struct ManualEntryPhotoGridView: View {
    @Bindable var store: ManualEntryStore
    @Binding var showCamera: Bool
    @Binding var fullScreenIndex: Int?

    @State private var libSelection: [PhotosPickerItem] = []
    private let thumbSize: CGFloat = 64

    private var canAddMore: Bool {
        store.photoEffects.photoPathsEditing.count < AppConfig.maxPhotosPerVisit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            photoThumbnails
            if canAddMore {
                photoButtons
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var photoThumbnails: some View {
        if !store.photoEffects.photoPathsEditing.isEmpty {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: thumbSize), spacing: 5)], spacing: 5) {
                ForEach(Array(store.photoEffects.photoPathsEditing.enumerated()), id: \.offset) { idx, path in
                    PhotoThumb(
                        path: path,
                        size: thumbSize,
                        showDelete: true,
                        onTap: { fullScreenIndex = idx },
                        onDelete: { handlePhotoDelete(at: idx) }
                    )
                }
            }
            .padding(.top, 2)
        }
    }

    private func handlePhotoDelete(at idx: Int) {
        store.removePhoto(at: idx)
        if fullScreenIndex == idx {
            fullScreenIndex = nil
        } else if let currentIndex = fullScreenIndex, currentIndex > idx {
            fullScreenIndex = currentIndex - 1
        }
    }

    private var photoButtons: some View {
        HStack(spacing: 12) {
            PhotosPicker(
                selection: $libSelection,
                maxSelectionCount: AppConfig.maxPhotosPerVisit - store.photoEffects.photoPathsEditing.count,
                matching: .images
            ) {
                Label(L.Photo.photo, systemImage: "photo.on.rectangle")
            }
            .onChange(of: libSelection) { _, _ in
                Task { await loadSelectedItems() }
            }

            Button {
                showCamera = true
            } label: {
                Label(L.Photo.camera, systemImage: "camera")
            }
            .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
        }
        .buttonStyle(.bordered)
    }

    @MainActor
    private func loadSelectedItems() async {
        guard !libSelection.isEmpty else { return }
        var images: [UIImage] = []
        images.reserveCapacity(libSelection.count)

        for item in libSelection {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }
        store.addPhotos(images)
        libSelection = []
    }
}

// MARK: - 緯度経度入力シート（後付け記録用）

private struct ManualEntryCoordinateInputSheet: View {
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
