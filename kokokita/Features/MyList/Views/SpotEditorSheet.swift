import SwiftUI
import MapKit
import PhotosUI
import CoreLocation
import Photos

/// スポット作成・編集シート
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

    // MARK: - UI 状態

    @Environment(\.dismiss) private var dismiss

    // スポット情報フォーム
    @State private var name: String = ""
    @State private var spotDescription: String = ""
    @State private var address: String = ""
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var spotImage: UIImage?
    @State private var imagePickerItem: PhotosPickerItem?
    @State private var useCustomRadius: Bool = false
    @State private var customRadius: Double = 150

    // 場所選択モード
    @State private var selectedMode: SpotLocationMode = .search

    // 場所名検索
    @State private var searchText: String = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching: Bool = false

    // 地図選択
    @State private var mapCameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    @State private var mapCenterCoordinate = CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503)

    // 写真からモード
    @State private var exifPhotoItem: PhotosPickerItem?
    @State private var exifMessage: String?

    // MARK: - 定数

    enum SpotLocationMode: String, CaseIterable {
        case search
        case map
        case photo
        var label: String {
            switch self {
            case .search: return L.SpotEditor.modeSearch
            case .map:    return L.SpotEditor.modeMap
            case .photo:  return L.SpotEditor.modePhoto
            }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // モード選択セグメント
                    Picker("", selection: $selectedMode) {
                        ForEach(SpotLocationMode.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    // 選択モードに応じたUI
                    Group {
                        switch selectedMode {
                        case .search: searchModeView
                        case .map:    mapModeView
                        case .photo:  photoModeView
                        }
                    }

                    Divider().padding(.top, 8)

                    // 共通スポット情報フォーム
                    spotInfoForm
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L.Common.cancel) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(saveButtonTitle) {
                        commitSave()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
        .task { loadInitialData() }
        .onChange(of: imagePickerItem) { _, item in loadSpotImage(from: item) }
        .onChange(of: exifPhotoItem) { _, item in loadExifLocation(from: item) }
    }

    // MARK: - ナビゲーションタイトル

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

    // MARK: - 場所名検索モード

    private var searchModeView: some View {
        VStack(spacing: 8) {
            // 検索フィールド
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(L.SpotEditor.searchPlaceholder, text: $searchText)
                    .autocorrectionDisabled()
                    .onSubmit { performSearch() }
                if isSearching {
                    ProgressView().scaleEffect(0.8)
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal)

            // 検索結果一覧
            if !searchResults.isEmpty {
                LazyVStack(spacing: 0) {
                    ForEach(searchResults, id: \.self) { item in
                        Button {
                            applyMapItem(item)
                        } label: {
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
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 16)
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 4)
                .padding(.horizontal)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - 地図選択モード

    private var mapModeView: some View {
        VStack(spacing: 8) {
            ZStack {
                Map(position: $mapCameraPosition) {}
                    .mapStyle(.standard)
                    .frame(height: 240)
                    .onMapCameraChange { ctx in
                        mapCenterCoordinate = ctx.region.center
                    }

                // 中央固定ピン
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.indigo)
                    .shadow(radius: 4)
                    .allowsHitTesting(false)
            }

            Button {
                selectMapCenter()
            } label: {
                Label(L.SpotEditor.selectLocation, systemImage: "checkmark.circle")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.indigo)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal)
        }
        .padding(.top, 4)
    }

    // MARK: - 写真からモード

    private var photoModeView: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $exifPhotoItem, matching: .images) {
                Label("写真を選択", systemImage: "photo.on.rectangle")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal)

            if let msg = exifMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            if let lat = latitude, let lon = longitude {
                Label("緯度: \(lat, specifier: "%.5f"), 経度: \(lon, specifier: "%.5f")", systemImage: "location.fill")
                    .font(.caption)
                    .foregroundStyle(.indigo)
                    .padding(.horizontal)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - 共通スポット情報フォーム

    private var spotInfoForm: some View {
        VStack(spacing: 0) {
            // 座標未設定の警告
            if latitude == nil || longitude == nil {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(L.SpotEditor.noCoordinateWarning)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1))
            }

            Group {
                // スポット名
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.SpotEditor.namePlaceholder)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    TextField(L.SpotEditor.namePlaceholder, text: $name)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }

                Divider().padding(.horizontal, 16)

                // 説明文
                TextField(L.SpotEditor.descriptionPlaceholder, text: $spotDescription, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                Divider().padding(.horizontal, 16)

                // 画像
                HStack {
                    Text(L.SpotEditor.image)
                        .foregroundStyle(.primary)
                    Spacer()
                    if let img = spotImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    PhotosPicker(selection: $imagePickerItem, matching: .images) {
                        Text(spotImage == nil ? L.Common.edit : "変更")
                            .font(.subheadline)
                            .foregroundStyle(.indigo)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Divider().padding(.horizontal, 16)

                // 達成判定半径
                VStack(spacing: 8) {
                    Toggle(L.SpotEditor.useCourseDefault, isOn: Binding(
                        get: { !useCustomRadius },
                        set: { useCustomRadius = !$0 }
                    ))
                    .tint(.indigo)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    if useCustomRadius {
                        VStack(spacing: 4) {
                            HStack {
                                Text(L.SpotEditor.recognitionRadius)
                                Spacer()
                                Text("\(Int(customRadius))m")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            .padding(.horizontal, 16)
                            Slider(value: $customRadius, in: 50...1000, step: 10)
                                .tint(.indigo)
                                .padding(.horizontal, 16)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .animation(.snappy, value: useCustomRadius)
            }
        }
        .padding(.bottom, 32)
    }

    // MARK: - 初期データ読み込み

    private func loadInitialData() {
        guard case .edit(let spot) = mode else { return }
        name = spot.name
        spotDescription = spot.spotDescription ?? ""
        address = spot.address ?? ""
        latitude = spot.latitude
        longitude = spot.longitude
        spotImage = spot.coverImage
        useCustomRadius = spot.useCustomRadius
        customRadius = spot.customRadius
        if let lat = spot.latitude, let lon = spot.longitude {
            mapCameraPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
            mapCenterCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    // MARK: - 場所名検索

    private func performSearch() {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        MKLocalSearch(request: request).start { response, _ in
            DispatchQueue.main.async {
                isSearching = false
                searchResults = response?.mapItems ?? []
            }
        }
    }

    private func applyMapItem(_ item: MKMapItem) {
        latitude = item.placemark.coordinate.latitude
        longitude = item.placemark.coordinate.longitude
        if name.isEmpty { name = item.name ?? "" }
        if address.isEmpty, let addr = item.placemark.thoroughfare {
            address = addr
        }
        searchResults = []
        searchText = ""
    }

    // MARK: - 地図選択

    private func selectMapCenter() {
        latitude = mapCenterCoordinate.latitude
        longitude = mapCenterCoordinate.longitude
        // 逆ジオコーディングで住所を取得
        let geocoder = CLGeocoder()
        let loc = CLLocation(latitude: mapCenterCoordinate.latitude, longitude: mapCenterCoordinate.longitude)
        geocoder.reverseGeocodeLocation(loc) { placemarks, _ in
            if let pm = placemarks?.first {
                let addr = [pm.thoroughfare, pm.locality].compactMap { $0 }.joined(separator: " ")
                if !addr.isEmpty { address = addr }
            }
        }
    }

    // MARK: - EXIF位置情報取得

    private func loadExifLocation(from item: PhotosPickerItem?) {
        guard let item else { return }
        exifMessage = nil
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
                  let gps = props[kCGImagePropertyGPSDictionary as String] as? [String: Any],
                  let lat = gps[kCGImagePropertyGPSLatitude as String] as? Double,
                  let lon = gps[kCGImagePropertyGPSLongitude as String] as? Double
            else {
                await MainActor.run {
                    exifMessage = L.SpotEditor.noExifLocation
                }
                return
            }
            let latRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String ?? "N"
            let lonRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String ?? "E"
            let finalLat = latRef == "S" ? -lat : lat
            let finalLon = lonRef == "W" ? -lon : lon
            await MainActor.run {
                latitude = finalLat
                longitude = finalLon
                exifMessage = "緯度: \(String(format: "%.5f", finalLat)), 経度: \(String(format: "%.5f", finalLon))"
            }
        }
    }

    // MARK: - スポット画像読み込み

    private func loadSpotImage(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                await MainActor.run { spotImage = img }
            }
        }
    }

    // MARK: - 保存

    private func commitSave() {
        let existingId: UUID?
        let existingPath: String?
        let existingUrl: String?

        switch mode {
        case .create:
            existingId = nil
            existingPath = nil
            existingUrl = nil
        case .edit(let spot):
            existingId = spot.existingId
            existingPath = spot.localCoverImagePath
            existingUrl = spot.coverImageUrl
        }

        var result = EditingSpot(
            id: existingId ?? UUID(),
            existingId: existingId,
            name: name,
            address: address.isEmpty ? nil : address,
            latitude: latitude,
            longitude: longitude,
            spotDescription: spotDescription.isEmpty ? nil : spotDescription,
            coverImage: spotImage,
            localCoverImagePath: existingPath,
            coverImageUrl: existingUrl,
            useCustomRadius: useCustomRadius,
            customRadius: customRadius
        )
        if existingId == nil { result.existingId = result.id }
        onSave(result)
        dismiss()
    }
}
