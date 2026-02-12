import SwiftUI
import MapKit

/// 場所検索シート
struct LocationSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false

    /// 場所選択時のコールバック（座標、住所、場所名）
    let onSelect: (CLLocationCoordinate2D, String?, String?) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 検索バー
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(L.ManualEntry.searchLocation, text: $searchText)
                        .textFieldStyle(.plain)
                        .submitLabel(.search)
                        .onSubmit {
                            Task { await search() }
                        }
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding()

                if isSearching {
                    ProgressView()
                        .padding()
                    Spacer()
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView {
                        Label(L.Confirmation.noPOIFound, systemImage: "mappin.slash")
                    }
                    Spacer()
                } else {
                    List(searchResults, id: \.self) { item in
                        Button {
                            selectItem(item)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name ?? "")
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                if let address = formatAddress(item.placemark) {
                                    Text(address)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(L.ManualEntry.searchLocation)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.Common.cancel) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func search() async {
        guard !searchText.isEmpty else { return }

        isSearching = true
        defer { isSearching = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.resultTypes = [.pointOfInterest, .address]

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            searchResults = response.mapItems
        } catch {
            Logger.warning("Location search failed: \(error)")
            searchResults = []
        }
    }

    private func selectItem(_ item: MKMapItem) {
        let coord = item.placemark.coordinate
        let address = formatAddress(item.placemark)
        let name = item.name
        onSelect(coord, address, name)
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
