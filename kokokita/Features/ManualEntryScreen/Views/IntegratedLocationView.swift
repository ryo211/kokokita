import SwiftUI
import MapKit

/// 検索+地図統合の場所選択ビュー
struct IntegratedLocationView: View {
    // 位置情報のバインディング
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    @Binding var addressLine: String?
    @Binding var placeName: String

    // 検索状態
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var showSearchResults = false
    @FocusState private var isSearchFieldFocused: Bool

    // 地図状態
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedCoordinate: CLLocationCoordinate2D?

    // 逆ジオコーディング
    private let geocoder = CLGeocoder()

    // 近くのPOI候補
    @State private var nearbyPOIs: [MKMapItem] = []
    @State private var isLoadingPOI = false

    // 現在位置が設定されているか
    private var hasLocation: Bool {
        latitude != nil && longitude != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // 検索バー
            searchBar

            // 地図エリア
            ZStack(alignment: .top) {
                mapView

                // 検索結果オーバーレイ
                if showSearchResults && !searchResults.isEmpty {
                    searchResultsOverlay
                }
            }

            // 近くの候補（POI）
            if hasLocation {
                nearbyPOICarousel
            }

            // 選択した場所の情報
            if hasLocation {
                selectedLocationInfo
            }
        }
        .onAppear {
            setupInitialPosition()
        }
        .onChange(of: latitude) { _, newLat in
            handleExternalLocationChange(newLat: newLat, newLon: longitude)
        }
        .onChange(of: longitude) { _, newLon in
            handleExternalLocationChange(newLat: latitude, newLon: newLon)
        }
    }

    /// 外部から位置情報が変更された場合の処理（写真取り込みなど）
    private func handleExternalLocationChange(newLat: Double?, newLon: Double?) {
        guard let lat = newLat, let lon = newLon else { return }

        let newCoord = CLLocationCoordinate2D(latitude: lat, longitude: lon)

        // 既に同じ座標が設定されている場合はスキップ
        if let current = selectedCoordinate,
           abs(current.latitude - lat) < 0.00001,
           abs(current.longitude - lon) < 0.00001 {
            return
        }

        // 地図の状態を更新
        selectedCoordinate = newCoord
        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: newCoord,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }

        // POI検索を実行
        Task { await searchNearbyPOI(at: newCoord) }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(L.LocationPicker.searchPlaceholder, text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isSearchFieldFocused)
                .submitLabel(.search)
                .onChange(of: searchText) { performSearch($1) }
                .onSubmit {
                    isSearchFieldFocused = false
                }

            if isSearching {
                ProgressView()
                    .scaleEffect(0.8)
            } else if !searchText.isEmpty {
                Button {
                    clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.vertical, 8)
        .onChange(of: isSearchFieldFocused) { _, focused in
            withAnimation(.easeInOut(duration: 0.2)) {
                showSearchResults = focused && !searchResults.isEmpty
            }
        }
    }

    // MARK: - Search Results Overlay

    private var searchResultsOverlay: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(searchResults.prefix(8), id: \.self) { item in
                        Button {
                            selectSearchResult(item)
                        } label: {
                            searchResultRow(for: item)
                        }
                        .buttonStyle(.plain)

                        if item != searchResults.prefix(8).last {
                            Divider()
                                .padding(.leading, 40)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 280)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func searchResultRow(for item: MKMapItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(.orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let address = formatAddress(item.placemark) {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - Map View

    private var mapView: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                if let coord = selectedCoordinate {
                    Marker("", coordinate: coord)
                        .tint(.orange)
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .onTapGesture { screenCoord in
                // 検索フォーカスを外す
                isSearchFieldFocused = false
                showSearchResults = false

                if let coordinate = proxy.convert(screenCoord, from: .local) {
                    selectCoordinate(coordinate)
                }
            }
        }
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            // 中央のクロスヘア（選択前の参考表示）
            Group {
                if selectedCoordinate == nil {
                    Image(systemName: "plus")
                        .font(.title)
                        .foregroundStyle(.orange.opacity(0.7))
                }
            }
        )
        .padding(.horizontal)
    }

    // MARK: - Nearby POI Carousel

    private var nearbyPOICarousel: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isLoadingPOI {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(L.Confirmation.loadingPOI)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            } else if !nearbyPOIs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(nearbyPOIs.prefix(8), id: \.self) { item in
                            Button {
                                selectNearbyPOI(item)
                            } label: {
                                poiChip(for: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.top, 8)
    }

    private func poiChip(for item: MKMapItem) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(.orange)
                .font(.caption)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name ?? "")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let category = item.pointOfInterestCategory?.localizedName {
                    Text(category)
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

    private func selectNearbyPOI(_ item: MKMapItem) {
        // 座標は変更せず、場所名と住所のみ更新
        placeName = item.name ?? ""
        if let address = formatAddress(item.placemark) {
            addressLine = address
        }
    }

    // MARK: - Selected Location Info

    private var selectedLocationInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    if !placeName.isEmpty {
                        Text(placeName)
                            .font(.subheadline.bold())
                    }

                    if let address = addressLine, !address.isEmpty {
                        Text(address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    if let lat = latitude, let lon = longitude {
                        Text(String(format: "%.5f, %.5f", lat, lon))
                            .font(.caption2)
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
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func performSearch(_ query: String) {
        searchTask?.cancel()

        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            withAnimation {
                showSearchResults = false
            }
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
                withAnimation {
                    showSearchResults = isSearchFieldFocused && !searchResults.isEmpty
                }
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

        // フォーカスを外して検索結果を非表示
        isSearchFieldFocused = false
        withAnimation {
            showSearchResults = false
        }
        searchText = ""
    }

    private func selectCoordinate(_ coordinate: CLLocationCoordinate2D) {
        selectedCoordinate = coordinate
        latitude = coordinate.latitude
        longitude = coordinate.longitude
        placeName = ""

        // 地図を移動
        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }

        // 逆ジオコーディングとPOI検索を並行実行
        Task {
            await reverseGeocode(coordinate: coordinate)
            await searchNearbyPOI(at: coordinate)
        }
    }

    private func setLocation(coordinate: CLLocationCoordinate2D, name: String?, address: String?) {
        selectedCoordinate = coordinate
        latitude = coordinate.latitude
        longitude = coordinate.longitude
        placeName = name ?? ""

        // 地図を移動
        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }

        if let address = address {
            addressLine = address
        } else {
            Task { await reverseGeocode(coordinate: coordinate) }
        }

        // POI検索を実行
        Task { await searchNearbyPOI(at: coordinate) }
    }

    private func reverseGeocode(coordinate: CLLocationCoordinate2D) async {
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

    private func clearSearch() {
        searchText = ""
        searchResults = []
        showSearchResults = false
    }

    private func clearLocation() {
        latitude = nil
        longitude = nil
        addressLine = nil
        placeName = ""
        selectedCoordinate = nil
        nearbyPOIs = []
    }

    private func searchNearbyPOI(at coordinate: CLLocationCoordinate2D) async {
        isLoadingPOI = true
        defer { isLoadingPOI = false }

        let request = MKLocalPointsOfInterestRequest(center: coordinate, radius: AppConfig.poiSearchRadius)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [
            .restaurant, .cafe, .bakery,
            .museum, .park, .nationalPark, .beach,
            .store, .hotel, .gasStation,
            .publicTransport, .airport, .hospital
        ])

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            nearbyPOIs = response.mapItems
        } catch {
            nearbyPOIs = []
        }
    }

    private func setupInitialPosition() {
        if let lat = latitude, let lon = longitude {
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            selectedCoordinate = coord
            cameraPosition = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
            // 初期位置でもPOI検索を実行
            Task { await searchNearbyPOI(at: coord) }
        } else {
            // 東京駅をデフォルト位置に
            let tokyo = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
            cameraPosition = .region(MKCoordinateRegion(
                center: tokyo,
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            ))
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

    IntegratedLocationView(
        latitude: $lat,
        longitude: $lon,
        addressLine: $address,
        placeName: $name
    )
}
