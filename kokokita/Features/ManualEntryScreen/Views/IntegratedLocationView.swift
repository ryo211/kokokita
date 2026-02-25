import SwiftUI
import MapKit

/// 検索+地図統合の場所選択ビュー
struct IntegratedLocationView: View {
    // 位置情報のバインディング
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    @Binding var addressLine: String?
    @Binding var placeName: String

    // 選択した場所の情報を表示するかどうか（デフォルトtrue）
    var showSelectedLocationInfo: Bool = true
    var onMapTapLocationSelected: (() -> Void)? = nil

    // 検索シート表示
    @State private var showLocationSearchSheet = false

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
            // 通常モード: 地図と場所情報を表示
            normalModeContent
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
        .sheet(isPresented: $showLocationSearchSheet) {
            LocationSearchSheet { coord, address, name in
                setLocation(coordinate: coord, name: name, address: address)
            }
        }
    }

    // MARK: - Normal Mode Content

    private var normalModeContent: some View {
        VStack(spacing: 0) {
            // 地図エリア
            mapView

            // 近くの候補（POI）
            if hasLocation {
                nearbyPOICarousel
            }

            // 選択した場所の情報（showSelectedLocationInfoがtrueの時のみ表示）
            if hasLocation && showSelectedLocationInfo {
                selectedLocationInfo
            }
        }
    }

    /// 外部から位置情報が変更された場合の処理（写真取り込みなど）
    private func handleExternalLocationChange(newLat: Double?, newLon: Double?) {
        guard let lat = newLat, let lon = newLon else {
            // 外部で場所がクリアされた場合、地図のピンも解除
            selectedCoordinate = nil
            nearbyPOIs = []
            return
        }

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
        Button {
            showLocationSearchSheet = true
        } label: {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                Text(L.ManualEntry.searchFieldPlaceholder)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.vertical, 8)
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
        // 座標、場所名、住所を候補場所に更新
        let coord = item.placemark.coordinate
        selectedCoordinate = coord
        latitude = coord.latitude
        longitude = coord.longitude
        placeName = item.name ?? ""
        if let address = formatAddress(item.placemark) {
            addressLine = address
        }

        // 地図を移動
        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            ))
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

        onMapTapLocationSelected?()
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
