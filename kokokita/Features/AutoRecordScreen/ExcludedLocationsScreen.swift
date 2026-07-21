import SwiftUI

/// 除外エリアの一覧と管理画面
struct ExcludedLocationsScreen: View {
    @State private var store = ExcludedLocationsStore()

    var body: some View {
        Group {
            if store.locations.isEmpty {
                emptyView
            } else {
                locationList
            }
        }
        .navigationTitle(L.AutoRecord.excludedLocationsTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { store.load() }
    }

    // MARK: - 空状態

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(L.AutoRecord.excludedLocationsEmpty)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - リスト

    private var locationList: some View {
        List {
            Section {
                ForEach(store.locations) { location in
                    ExcludedLocationRow(location: location)
                }
                .onDelete { indexSet in
                    store.delete(at: indexSet)
                }
            } footer: {
                Text(L.AutoRecord.excludedLocationsFooter)
            }
        }
    }
}

// MARK: - 行ビュー

private struct ExcludedLocationRow: View {
    let location: ExcludedLocation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(location.displayLabel)
                .font(.body)
            HStack(spacing: 8) {
                Text(L.AutoRecord.excludedLocationsRadius(Int(location.radiusMeters)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.secondary)
                Text(location.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Store

@Observable
private final class ExcludedLocationsStore {
    private let repo = AppContainer.shared.excludedLocationRepo

    var locations: [ExcludedLocation] = []

    func load() {
        locations = (try? repo.fetchAll()) ?? []
    }

    func delete(at indexSet: IndexSet) {
        for index in indexSet {
            let location = locations[index]
            try? repo.delete(id: location.id)
        }
        locations.remove(atOffsets: indexSet)
    }
}
