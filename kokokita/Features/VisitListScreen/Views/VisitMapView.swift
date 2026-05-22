import SwiftUI
import MapKit

struct VisitMapView: View {
    private static let zoomOnVisitFocusKey = "visitList.map.zoomOnVisitFocus"

    let items: [VisitAggregate]
    let labelMap: [UUID: String]
    let groupMap: [UUID: String]
    let memberMap: [UUID: String]
    var labelColorMap: [String: Color] = [:]
    @Binding var selectedItemId: UUID?
    @Binding var sheetHeight: CGFloat
    let onShowDetail: (UUID) -> Void

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var locationService = DefaultLocationService()
    @State private var isLoadingLocation = false
    @State private var showCurrentLocation = false
    @State private var currentLocation: CLLocationCoordinate2D?
    @State private var currentMapRegion: MKCoordinateRegion?
    @State private var showMapSettings = false
    @AppStorage(Self.zoomOnVisitFocusKey) private var zoomOnVisitFocus = true

    // 選択されたアイテムを最後に配置するようソート（最前面に描画）
    private var sortedItems: [VisitAggregate] {
        items.sorted { item1, item2 in
            let isItem1Selected = item1.id == selectedItemId
            let isItem2Selected = item2.id == selectedItemId
            if isItem1Selected == isItem2Selected { return false }
            return isItem2Selected
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 上部 2/3：地図
            ZStack(alignment: .topTrailing) {
                Map(position: $cameraPosition) {
                    ForEach(sortedItems) { agg in
                        if agg.visit.latitude != 0 || agg.visit.longitude != 0 {
                            let isSelected = selectedItemId == agg.id
                            let pinColor = firstLabelColor(for: agg)
                            Annotation("", coordinate: CLLocationCoordinate2D(
                                latitude: agg.visit.latitude,
                                longitude: agg.visit.longitude
                            )) {
                                MapPinView(isSelected: isSelected, pinColor: pinColor)
                                    .onTapGesture {
                                        selectedItemId = (selectedItemId == agg.id ? nil : agg.id)
                                    }
                            }
                            .annotationTitles(.hidden)
                        }
                    }

                    // 現在地のピン
                    if showCurrentLocation, let location = currentLocation {
                        Annotation("現在地", coordinate: location) {
                            CurrentLocationPinView()
                        }
                        .annotationTitles(.hidden)
                    }
                }
                .mapStyle(.standard)
                .onMapCameraChange { context in
                    currentMapRegion = context.region
                }

                // 右上ボタン群
                VStack(spacing: 10) {
                    mapSettingsButton
                    currentLocationButton
                }
                .padding(.trailing, 16)
                .padding(.top, 16)
            }
            .containerRelativeFrame(.vertical, count: 2, span: 1, spacing: 0)

            Divider()

            // 下部 1/3：記録リスト
            if items.isEmpty {
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(items, id: \.id) { visit in
                            visitRowView(for: visit)
                                .id(visit.id)
                        }
                    }
                    .listStyle(.plain)
                    .onChange(of: selectedItemId) { _, newId in
                        if let newId {
                            withAnimation { proxy.scrollTo(newId, anchor: .center) }
                        }
                    }
                }
            }
        }
        .task {
            if let id = selectedItemId {
                focusOnItem(id: id, animated: false)
            } else {
                updateCameraPosition()
            }
        }
        .onChange(of: items) {
            updateCameraPosition()
        }
        .onChange(of: selectedItemId) { _, newId in
            if let newId {
                focusOnItem(id: newId, animated: true)
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    updateCameraPosition()
                }
            }
        }
        .sheet(isPresented: $showMapSettings) {
            VisitMapSettingsSheet(zoomOnVisitFocus: $zoomOnVisitFocus)
        }
    }

    // MARK: - Row View

    @ViewBuilder
    private func visitRowView(for visit: VisitAggregate) -> some View {
        let isFocused = selectedItemId == visit.id
        HStack(spacing: 0) {
            VisitRow(agg: visit, nameResolver: nameResolver, compact: true, labelColorMap: labelColorMap)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedItemId = (selectedItemId == visit.id ? nil : visit.id)
                }
            Button {
                onShowDetail(visit.id)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .listRowBackground(isFocused ? Color.blue.opacity(0.1) : nil)
    }

    private func nameResolver(_ labelIds: [UUID], _ groupId: UUID?, _ memberIds: [UUID]) -> (labels: [String], group: String?, members: [String]) {
        let labels = labelIds.compactMap { labelMap[$0] }
        let group = groupId.flatMap { groupMap[$0] }
        let members = memberIds.compactMap { memberMap[$0] }
        return (labels, group, members)
    }

    // MARK: - Map Helpers

    /// 訪問記録の先頭ラベル色を取得
    private func firstLabelColor(for agg: VisitAggregate) -> Color? {
        let names = agg.details.labelIds
            .compactMap { labelMap[$0] }
            .sorted { $0.localizedCompare($1) == .orderedAscending }
        guard let firstName = names.first else { return nil }
        return labelColorMap[firstName]
    }

    /// 指定IDのピンにカメラをフォーカス
    private func focusOnItem(id: UUID, animated: Bool) {
        guard let agg = items.first(where: { $0.id == id }),
              agg.visit.latitude != 0 || agg.visit.longitude != 0 else { return }
        let center = CLLocationCoordinate2D(latitude: agg.visit.latitude, longitude: agg.visit.longitude)
        let region: MKCoordinateRegion
        if zoomOnVisitFocus {
            region = MKCoordinateRegion(center: center, latitudinalMeters: 500, longitudinalMeters: 500)
        } else if let currentMapRegion {
            region = MKCoordinateRegion(center: center, span: currentMapRegion.span)
        } else {
            region = MKCoordinateRegion(center: center, latitudinalMeters: 1000, longitudinalMeters: 1000)
        }
        if animated {
            withAnimation(.easeInOut(duration: 0.3)) {
                cameraPosition = .region(region)
            }
        } else {
            cameraPosition = .region(region)
        }
    }

    private func updateCameraPosition() {
        let validCoordinates = items.compactMap { agg -> CLLocationCoordinate2D? in
            guard agg.visit.latitude != 0 || agg.visit.longitude != 0 else { return nil }
            return CLLocationCoordinate2D(latitude: agg.visit.latitude, longitude: agg.visit.longitude)
        }

        guard !validCoordinates.isEmpty else {
            cameraPosition = .automatic
            return
        }

        if validCoordinates.count == 1 {
            cameraPosition = .region(MKCoordinateRegion(
                center: validCoordinates[0],
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            ))
        } else {
            let rect = validCoordinates.reduce(MKMapRect.null) { rect, coord in
                let point = MKMapPoint(coord)
                return rect.union(MKMapRect(x: point.x, y: point.y, width: 0, height: 0))
            }
            cameraPosition = .rect(rect.insetBy(dx: -rect.size.width * 0.1, dy: -rect.size.height * 0.1))
        }
    }

    // MARK: - Map Settings Button

    private var mapSettingsButton: some View {
        Button {
            showMapSettings = true
        } label: {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.12), Color.white.opacity(0.03)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.2), Color.white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
                .frame(width: 44, height: 44)
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                .overlay {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.blue)
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Current Location Button

    private var currentLocationButton: some View {
        Button {
            Task { await toggleCurrentLocation() }
        } label: {
            ZStack {
                if showCurrentLocation {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.95), Color.blue.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.25), Color.clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                        .frame(width: 44, height: 44)
                        .shadow(color: Color.blue.opacity(0.35), radius: 8, x: 0, y: 2)
                        .shadow(color: Color.blue.opacity(0.15), radius: 3, x: 0, y: 1)
                } else {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.03)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.2), Color.white.opacity(0.08)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        }
                        .frame(width: 44, height: 44)
                        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                }

                if isLoadingLocation {
                    ProgressView()
                        .tint(showCurrentLocation ? .white : .blue)
                } else {
                    Image(systemName: showCurrentLocation ? "location.fill" : "location")
                        .font(.system(size: 20))
                        .foregroundStyle(showCurrentLocation ? .white : .blue)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.interpolatingSpring(stiffness: 200, damping: 20), value: showCurrentLocation)
    }

    private func toggleCurrentLocation() async {
        if showCurrentLocation {
            withAnimation {
                showCurrentLocation = false
                currentLocation = nil
            }
        } else {
            await fetchAndShowCurrentLocation()
        }
    }

    private func fetchAndShowCurrentLocation() async {
        isLoadingLocation = true
        defer { isLoadingLocation = false }

        do {
            let (location, _) = try await locationService.requestOneShotLocation()
            let coordinate = location.coordinate
            currentLocation = coordinate

            withAnimation {
                showCurrentLocation = true
                if let existingRegion = currentMapRegion {
                    cameraPosition = .region(MKCoordinateRegion(center: coordinate, span: existingRegion.span))
                } else {
                    cameraPosition = .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000))
                }
            }
        } catch {
            Logger.error("Failed to get current location", error: error)
        }
    }
}

// MARK: - Map Settings Sheet

private struct VisitMapSettingsSheet: View {
    @Binding var zoomOnVisitFocus: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("記録フォーカス時のズーム")
                        .font(.headline)
                    Text("地図上の記録を選択したときに、その記録を中心に表示しながらズームインするかを切り替えます。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 0) {
                    toggleButton(title: "ON", isSelected: zoomOnVisitFocus) {
                        withAnimation(.easeInOut(duration: 0.18)) { zoomOnVisitFocus = true }
                    }
                    toggleButton(title: "OFF", isSelected: !zoomOnVisitFocus) {
                        withAnimation(.easeInOut(duration: 0.18)) { zoomOnVisitFocus = false }
                    }
                }
                .padding(4)
                .background(Color.secondary.opacity(0.12), in: Capsule())

                Spacer()
            }
            .padding(20)
            .navigationTitle("地図設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L.Common.done) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(220)])
    }

    private func toggleButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(isSelected ? Color.indigo : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Map Pin View

struct MapPinView: View {
    let isSelected: Bool
    var pinColor: Color?

    private var baseColor: Color { pinColor ?? .red }

    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(baseColor.opacity(0.3))
                    .frame(width: 36, height: 36)
            }
            Circle()
                .fill(baseColor)
                .frame(width: isSelected ? 28 : 16, height: isSelected ? 28 : 16)
            Circle()
                .stroke(Color.white, lineWidth: isSelected ? 3 : 2)
                .frame(width: isSelected ? 28 : 16, height: isSelected ? 28 : 16)
        }
        .shadow(color: isSelected ? baseColor.opacity(0.5) : Color.black.opacity(0.3),
                radius: isSelected ? 6 : 2)
    }
}

// MARK: - Current Location Pin View

struct CurrentLocationPinView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 32, height: 32)
            Circle()
                .fill(Color.green)
                .frame(width: 16, height: 16)
            Circle()
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 16, height: 16)
        }
        .shadow(radius: 3)
    }
}
