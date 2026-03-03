import SwiftUI
import MapKit

/// 地図タップで場所を選択するシート
struct ManualEntryMapPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var isSearchingPOI = false
    @State private var poiResults: [MKMapItem] = []

    /// 初期位置（オプション）
    var initialCoordinate: CLLocationCoordinate2D?

    /// 場所選択時のコールバック（座標、POI名、POI住所）
    let onSelect: (CLLocationCoordinate2D, String?, String?) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
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
                            selectedCoordinate = coordinate
                            // ピンを立てたらPOI検索を実行
                            Task { await searchNearbyPOI(at: coordinate) }
                        }
                    }
                }

                // 中央のクロスヘア（選択前の参考表示）
                if selectedCoordinate == nil {
                    Image(systemName: "plus")
                        .font(.title)
                        .foregroundStyle(.orange)
                }

                // 下部のパネル
                VStack {
                    Spacer()
                    if let coord = selectedCoordinate {
                        bottomPanel(for: coord)
                    }
                }
            }
            .navigationTitle(L.ManualEntry.tapOnMap)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.Common.cancel) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                setupInitialPosition()
            }
        }
    }

    // MARK: - Bottom Panel

    @ViewBuilder
    private func bottomPanel(for coord: CLLocationCoordinate2D) -> some View {
        VStack(spacing: 0) {
            // POI検索結果
            if isSearchingPOI {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(L.Confirmation.loadingPOI)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
            } else if !poiResults.isEmpty {
                poiListView
            }

            Divider()

            // 座標表示と確定ボタン
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%.5f, %.5f", coord.latitude, coord.longitude))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    onSelect(coord, nil, nil)
                    dismiss()
                } label: {
                    Text(L.ManualEntry.useThisLocation)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.orange)
                        .clipShape(Capsule())
                }
            }
            .padding()
        }
        .background(.regularMaterial)
    }

    // MARK: - POI List

    private var poiListView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(poiResults.prefix(5), id: \.self) { item in
                    Button {
                        selectPOI(item)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name ?? "")
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            if let category = item.pointOfInterestCategory?.localizedName {
                                Text(category)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func setupInitialPosition() {
        if let coord = initialCoordinate {
            cameraPosition = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
            selectedCoordinate = coord
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

    // MARK: - POI Search

    private func searchNearbyPOI(at coordinate: CLLocationCoordinate2D) async {
        isSearchingPOI = true
        poiResults = []

        defer { isSearchingPOI = false }

        let request = MKLocalPointsOfInterestRequest(center: coordinate, radius: AppConfig.poiSearchRadius)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [
            .restaurant, .cafe, .bakery,
            .museum, .park, .nationalPark, .beach,
            .store, .hotel, .gasStation
        ])

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            poiResults = response.mapItems
        } catch {
            // エラーは無視（POIが見つからない場合もある）
        }
    }

    private func selectPOI(_ item: MKMapItem) {
        guard let coord = selectedCoordinate else { return }
        let name = item.name
        let address = formatAddress(item.placemark)
        onSelect(coord, name, address)
        dismiss()
    }

    private func formatAddress(_ placemark: MKPlacemark) -> String? {
        var components: [String] = []
        if let admin = placemark.administrativeArea { components.append(admin) }
        if let locality = placemark.locality { components.append(locality) }
        if let subLocality = placemark.subLocality { components.append(subLocality) }
        if let thoroughfare = placemark.thoroughfare { components.append(thoroughfare) }
        if let subThoroughfare = placemark.subThoroughfare { components.append(subThoroughfare) }
        return components.isEmpty ? nil : components.joined()
    }
}
