import SwiftUI
import MapKit
import PhotosUI

/// 場所設定シート
/// コース機能や後付け記録など、複数の画面で再利用可能な汎用コンポーネント
struct LocationPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    // 位置情報のバインディング
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    @Binding var addressLine: String?
    @Binding var placeName: String

    // 写真から取り込み時のコールバック（日時と写真も返す）
    // nilの場合は写真取り込みボタンを表示しない
    var onPhotoImport: ((_ coordinate: CLLocationCoordinate2D?, _ timestamp: Date?, _ image: UIImage?) -> Void)?

    // 検索状態
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var isSearchFieldFocused: Bool

    // 地図選択シート
    @State private var showMapPicker = false

    // 周辺施設検索
    @State private var showNearbyPOI = false
    @State private var nearbyPOIs: [MKMapItem] = []
    @State private var isLoadingNearbyPOI = false

    // 写真選択
    @State private var photoSelection: PhotosPickerItem?
    @State private var importedPhotoImage: UIImage?

    // 現在位置が設定されているか
    private var hasLocation: Bool {
        latitude != nil && longitude != nil
    }

    // 現在の座標
    private var currentCoordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var body: some View {
        NavigationStack {
            List {
                // 場所を検索
                searchSection

                // 地図から選択
                mapPickerSection

                // 写真から取り込み（オプション）
                if onPhotoImport != nil {
                    photoImportSection
                }
            }
            .safeAreaInset(edge: .bottom) {
                currentLocationBottomPanel
            }
            .navigationTitle(L.ManualEntry.setLocation)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.Common.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.Common.done) { dismiss() }
                        .fontWeight(.bold)
                        .disabled(!hasLocation)
                }
            }
            .sheet(isPresented: $showMapPicker) { mapPickerSheet }
            .sheet(isPresented: $showNearbyPOI) { nearbyPOISheet }
            .onChange(of: photoSelection) { handlePhotoSelection($1) }
        }
    }

    // MARK: - Current Location Bottom Panel

    private var currentLocationBottomPanel: some View {
        VStack(spacing: 0) {
            Divider()

            VStack(alignment: .leading, spacing: 12) {
                // ヘッダー
                Text(L.LocationPicker.currentLocation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                if hasLocation {
                    // 設定済みの場合
                    HStack(alignment: .top, spacing: 12) {
                        // 写真サムネイル（写真から取り込み時のみ表示）
                        if let image = importedPhotoImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        // 場所情報
                        VStack(alignment: .leading, spacing: 8) {
                            // 場所名 + 候補を探すボタン（常に表示）
                            HStack {
                                Image(systemName: "building.2")
                                    .foregroundStyle(.orange)

                                if !placeName.isEmpty {
                                    Text(placeName)
                                        .font(.subheadline.bold())
                                }

                                Spacer()

                                // 周辺施設検索ボタン
                                Button {
                                    Task { await searchNearbyPOI() }
                                    showNearbyPOI = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "sparkle.magnifyingglass")
                                        Text(L.LocationPicker.findNearbySpots)
                                    }
                                    .font(.subheadline)
                                    .foregroundStyle(.orange)
                                }
                                .buttonStyle(.plain)
                            }

                            // 住所・緯度経度 + クリアボタン
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundStyle(.secondary)

                                VStack(alignment: .leading, spacing: 2) {
                                    if let address = addressLine, !address.isEmpty {
                                        Text(address)
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                    }
                                    if let lat = latitude, let lon = longitude {
                                        Text(String(format: "%.5f, %.5f", lat, lon))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                // クリアボタン
                                Button {
                                    clearLocation()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                        .imageScale(.medium)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else {
                    // 未設定の場合
                    HStack {
                        Image(systemName: "mappin.slash")
                            .foregroundStyle(.secondary)
                        Text(L.Common.notSelected)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(.regularMaterial)
        }
    }

    private func clearLocation() {
        latitude = nil
        longitude = nil
        addressLine = nil
        placeName = ""
        importedPhotoImage = nil
    }

    // MARK: - Search Section

    private var searchSection: some View {
        Section {
            // 検索入力欄
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(L.LocationPicker.searchPlaceholder, text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isSearchFieldFocused)
                    .onChange(of: searchText) { performSearch($1) }
                    .onChange(of: isSearchFieldFocused) { _, focused in
                        // フォーカス時に検索を再実行
                        if focused && !searchText.isEmpty {
                            performSearch(searchText)
                        }
                    }

                if isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if !searchText.isEmpty {
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

            // 検索結果（フォーカス中のみ表示）
            if isSearchFieldFocused {
                if !searchResults.isEmpty {
                    ForEach(searchResults.prefix(10), id: \.self) { item in
                        Button {
                            selectSearchResult(item)
                        } label: {
                            searchResultRow(for: item)
                        }
                        .buttonStyle(.plain)
                    }
                } else if !searchText.isEmpty && !isSearching {
                    Text(L.LocationPicker.noResults)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(L.ManualEntry.searchLocation)
        }
    }

    private func searchResultRow(for item: MKMapItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.name ?? "")
                .font(.subheadline)
                .foregroundStyle(.primary)

            if let address = formatAddress(item.placemark) {
                Text(address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Map Picker Section

    private var mapPickerSection: some View {
        Section {
            Button {
                showMapPicker = true
            } label: {
                Label(L.ManualEntry.tapOnMap, systemImage: "map")
            }
        }
    }

    // MARK: - Photo Import Section

    private var photoImportSection: some View {
        Section {
            PhotosPicker(
                selection: $photoSelection,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label(L.ManualEntry.importFromPhoto, systemImage: "photo.on.rectangle")
            }
        } footer: {
            Text(L.LocationPicker.photoImportDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Map Picker Sheet

    private var mapPickerSheet: some View {
        ManualEntryMapPickerSheet(initialCoordinate: currentCoordinate) { coord, name, address in
            setLocation(coordinate: coord, name: name, address: address)
        }
    }

    // MARK: - Nearby POI Sheet

    private var nearbyPOISheet: some View {
        NavigationStack {
            List {
                if isLoadingNearbyPOI {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(L.Confirmation.loadingPOI)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if nearbyPOIs.isEmpty {
                    Text(L.Confirmation.noPOIFound)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(nearbyPOIs, id: \.self) { item in
                        Button {
                            selectNearbyPOI(item)
                        } label: {
                            nearbyPOIRow(for: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(L.LocationPicker.nearbySpots)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.Common.close) { showNearbyPOI = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func nearbyPOIRow(for item: MKMapItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.name ?? "")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                if let category = item.pointOfInterestCategory?.localizedName {
                    Text(category)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())
                }
            }

            if let address = formatAddress(item.placemark) {
                Text(address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func performSearch(_ query: String) {
        searchTask?.cancel()

        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }

        searchTask = Task {
            isSearching = true
            defer { isSearching = false }

            // デバウンス
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }

            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.resultTypes = [.pointOfInterest, .address]

            do {
                let search = MKLocalSearch(request: request)
                let response = try await search.start()
                guard !Task.isCancelled else { return }
                searchResults = response.mapItems
            } catch {
                guard !Task.isCancelled else { return }
                searchResults = []
            }
        }
    }

    private func selectSearchResult(_ item: MKMapItem) {
        let coord = item.placemark.coordinate
        let name = item.name
        let address = formatAddress(item.placemark)

        setLocation(coordinate: coord, name: name, address: address)

        // フォーカスを外す（検索キーワードは残す）
        isSearchFieldFocused = false
    }

    private func setLocation(coordinate: CLLocationCoordinate2D, name: String?, address: String?) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude

        // 場所名は常に上書き（nilの場合は空文字）
        placeName = name ?? ""

        // 検索や地図から選択した場合は写真をクリア
        importedPhotoImage = nil

        if let address = address {
            addressLine = address
        } else {
            // 住所がない場合は逆ジオコーディング
            Task { await reverseGeocode(coordinate: coordinate) }
        }
    }

    private func reverseGeocode(coordinate: CLLocationCoordinate2D) async {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let pm = placemarks.first {
                addressLine = formatPlacemark(pm)
            }
        } catch {
            // エラーは無視
        }
    }

    private func searchNearbyPOI() async {
        guard let coord = currentCoordinate else { return }

        isLoadingNearbyPOI = true
        defer { isLoadingNearbyPOI = false }

        let request = MKLocalPointsOfInterestRequest(center: coord, radius: AppConfig.poiSearchRadius)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [
            .restaurant, .cafe, .bakery,
            .museum, .park, .nationalPark, .beach,
            .store, .hotel, .gasStation
        ])

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            nearbyPOIs = response.mapItems
        } catch {
            nearbyPOIs = []
        }
    }

    private func selectNearbyPOI(_ item: MKMapItem) {
        let name = item.name
        let address = formatAddress(item.placemark)

        // 座標は変更せず、名前と住所を上書き
        placeName = name ?? ""
        if let address = address {
            addressLine = address
        }

        showNearbyPOI = false
    }

    private func handlePhotoSelection(_ item: PhotosPickerItem?) {
        guard let item = item, let onPhotoImport = onPhotoImport else { return }

        Task {
            // 現在の設定をリセット
            clearLocation()

            // 写真を読み込んでサムネイル用に保持
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                importedPhotoImage = image
            }

            let exifData = await ExifEffects.extractExifDataFromPhotosPickerItem(item)

            // 位置情報がある場合は設定
            if let coord = exifData.coordinate {
                latitude = coord.latitude
                longitude = coord.longitude
                // 写真には場所名がないのでplaceNameは空のまま
                await reverseGeocode(coordinate: coord)
            }

            // コールバックで座標、日時、写真を返す（エラーメッセージは親側で表示）
            onPhotoImport(exifData.coordinate, exifData.timestamp, importedPhotoImage)

            photoSelection = nil
        }
    }

    // MARK: - Helpers

    private func formatAddress(_ placemark: MKPlacemark) -> String? {
        var components: [String] = []
        if let admin = placemark.administrativeArea { components.append(admin) }
        if let locality = placemark.locality { components.append(locality) }
        if let subLocality = placemark.subLocality { components.append(subLocality) }
        if let thoroughfare = placemark.thoroughfare { components.append(thoroughfare) }
        if let subThoroughfare = placemark.subThoroughfare { components.append(subThoroughfare) }
        return components.isEmpty ? nil : components.joined()
    }

    private func formatPlacemark(_ placemark: CLPlacemark) -> String? {
        var components: [String] = []
        if let admin = placemark.administrativeArea { components.append(admin) }
        if let locality = placemark.locality { components.append(locality) }
        if let subLocality = placemark.subLocality { components.append(subLocality) }
        if let thoroughfare = placemark.thoroughfare { components.append(thoroughfare) }
        if let subThoroughfare = placemark.subThoroughfare { components.append(subThoroughfare) }
        return components.isEmpty ? nil : components.joined()
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var lat: Double? = 35.6812
    @Previewable @State var lon: Double? = 139.7671
    @Previewable @State var address: String? = "東京都千代田区"
    @Previewable @State var name: String = ""

    LocationPickerSheet(
        latitude: $lat,
        longitude: $lon,
        addressLine: $address,
        placeName: $name
    ) { coord, timestamp, image in
        print("Photo imported: \(String(describing: coord)), \(String(describing: timestamp)), image: \(image != nil)")
    }
}
