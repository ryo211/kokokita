import SwiftUI
import MapKit

/// 場所検索シート
struct LocationSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var hasSearched = false
    @FocusState private var isSearchFieldFocused: Bool

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
                        .focused($isSearchFieldFocused)
                        .submitLabel(.search)
                        .onSubmit {
                            let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            searchTask?.cancel()
                            searchTask = Task { await search(query: trimmed) }
                        }
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                            hasSearched = false
                            searchTask?.cancel()
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

                ScrollView {
                    LazyVStack(spacing: 0) {
                        if isSearching {
                            VStack(spacing: 12) {
                                ProgressView()
                                Text(L.Common.loading)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                        } else if searchResults.isEmpty {
                            let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmed.isEmpty || !hasSearched {
                                VStack(spacing: 16) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 40))
                                        .foregroundStyle(.secondary)
                                    Text(L.LocationPicker.searchPlaceholder)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
                            } else {
                                VStack(spacing: 16) {
                                    Image(systemName: "mappin.slash")
                                        .font(.system(size: 40))
                                        .foregroundStyle(.secondary)
                                    Text(L.LocationPicker.noResults)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
                            }
                        } else {
                            ForEach(searchResults, id: \.self) { item in
                                Button {
                                    selectItem(item)
                                } label: {
                                    searchResultRow(for: item)
                                }
                                .buttonStyle(.plain)

                                Divider()
                                    .padding(.leading, 52)
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .padding(.horizontal)
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
            .onAppear {
                requestInitialFocus()
            }
            .onDisappear {
                searchTask?.cancel()
            }
        }
    }

    private func searchResultRow(for item: MKMapItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName(for: item.pointOfInterestCategory))
                .foregroundStyle(.orange)
                .font(.title2)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name ?? "")
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let address = formatAddress(item.placemark) {
                    Text(address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let category = item.pointOfInterestCategory?.localizedName {
                    Text(category)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func search(query: String) async {
        isSearching = true
        defer { isSearching = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest, .address]

        do {
            let mkSearch = MKLocalSearch(request: request)
            let response = try await mkSearch.start()
            guard !Task.isCancelled else { return }
            searchResults = response.mapItems
            hasSearched = true
        } catch {
            guard !Task.isCancelled else { return }
            Logger.warning("Location search failed: \(error)")
            searchResults = []
            hasSearched = true
        }
    }

    private func symbolName(for category: MKPointOfInterestCategory?) -> String {
        guard let category else { return "mappin.circle.fill" }
        switch category {
        case .restaurant: return "fork.knife.circle.fill"
        case .cafe, .bakery: return "cup.and.saucer.fill"
        case .hotel: return "bed.double.circle.fill"
        case .gasStation: return "fuelpump.circle.fill"
        case .hospital: return "cross.case.circle.fill"
        case .park, .nationalPark: return "leaf.circle.fill"
        case .museum: return "building.columns.circle.fill"
        case .publicTransport, .airport: return "tram.circle.fill"
        case .store, .foodMarket: return "bag.circle.fill"
        case .school, .university: return "graduationcap.circle.fill"
        case .parking: return "parkingsign.circle.fill"
        default: return "mappin.circle.fill"
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

    private func requestInitialFocus() {
        isSearchFieldFocused = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 30_000_000)
            if !isSearchFieldFocused {
                isSearchFieldFocused = true
            }
        }
    }
}
