import SwiftUI
import MapKit

// シートの高さを伝えるためのPreferenceKey
struct SheetHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct HomeMapView: View {
    let items: [VisitAggregate]
    let labelMap: [UUID: String]
    let groupMap: [UUID: String]
    let memberMap: [UUID: String]
    @Binding var selectedItemId: UUID?
    @Binding var sheetHeight: CGFloat
    let onShowDetail: (UUID) -> Void

    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition) {
                ForEach(items) { agg in
                    if agg.visit.latitude != 0 || agg.visit.longitude != 0 {
                        Annotation("", coordinate: CLLocationCoordinate2D(
                            latitude: agg.visit.latitude,
                            longitude: agg.visit.longitude
                        )) {
                            MapPinView(isSelected: selectedItemId == agg.id)
                                .onTapGesture {
                                    selectedItemId = agg.id
                                }
                        }
                    }
                }
            }
            .mapStyle(.standard)

            // 下部詳細シート
            if let selectedId = selectedItemId,
               let selected = items.first(where: { $0.id == selectedId }) {
                VisitMapDetailSheet(
                    aggregate: selected,
                    labelMap: labelMap,
                    groupMap: groupMap,
                    memberMap: memberMap,
                    onClose: {
                        selectedItemId = nil
                    },
                    onTap: {
                        onShowDetail(selectedId)
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.25), value: selectedItemId)
            }
        }
        .onPreferenceChange(SheetHeightPreferenceKey.self) { height in
            sheetHeight = height
        }
        .task {
            updateCameraPosition()
        }
        .onChange(of: items) { _ in
            updateCameraPosition()
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
            // 1件だけの場合は中心に配置
            let center = validCoordinates[0]
            let region = MKCoordinateRegion(
                center: center,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )
            cameraPosition = .region(region)
        } else {
            // 複数の場合は全て収まるように
            let rect = validCoordinates.reduce(MKMapRect.null) { rect, coord in
                let point = MKMapPoint(coord)
                let pointRect = MKMapRect(x: point.x, y: point.y, width: 0, height: 0)
                return rect.union(pointRect)
            }

            // 少し余白を持たせる
            let paddedRect = rect.insetBy(dx: -rect.size.width * 0.1, dy: -rect.size.height * 0.1)
            cameraPosition = .rect(paddedRect)
        }
    }
}

// MARK: - Map Pin View
struct MapPinView: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.blue : Color.red)
                .frame(width: isSelected ? 20 : 16, height: isSelected ? 20 : 16)

            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: isSelected ? 20 : 16, height: isSelected ? 20 : 16)
        }
        .shadow(radius: 2)
    }
}

// MARK: - Detail Sheet
struct VisitMapDetailSheet: View {
    let aggregate: VisitAggregate
    let labelMap: [UUID: String]
    let groupMap: [UUID: String]
    let memberMap: [UUID: String]
    let onClose: () -> Void
    let onTap: () -> Void

    @State private var dragOffset: CGFloat = 0

    private var title: String {
        if let t = aggregate.details.title, !t.isEmpty {
            return t
        }
        if let f = aggregate.details.facilityName, !f.isEmpty {
            return f
        }
        return "（タイトルなし）"
    }

    var body: some View {
        VStack(spacing: 0) {
            // ドラッグハンドル
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 12)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(2)

                    Text(aggregate.visit.timestampUTC.kokokitaVisitString)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let address = aggregate.details.resolvedAddress {
                        Text(address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    // ラベル/グループ/メンバー
                    HStack(spacing: 6) {
                        if let gid = aggregate.details.groupId, let gname = groupMap[gid] {
                            Chip(gname, kind: .group, size: .small, showRemoveButton: false)
                        }
                        ForEach(aggregate.details.labelIds.prefix(2), id: \.self) { lid in
                            if let lname = labelMap[lid] {
                                Chip(lname, kind: .label, size: .small, showRemoveButton: false)
                            }
                        }
                    }
                }

                Spacer()

                // 閉じるボタン
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 8)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .offset(y: dragOffset)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    // 下方向のドラッグのみ許可
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    // 100pt以上下に引っ張ったら閉じる
                    if value.translation.height > 100 {
                        onClose()
                    }
                    // 元の位置に戻す
                    withAnimation(.easeOut(duration: 0.2)) {
                        dragOffset = 0
                    }
                }
        )
        .overlay(
            GeometryReader { geometry in
                Color.clear
                    .preference(
                        key: SheetHeightPreferenceKey.self,
                        value: geometry.size.height
                    )
            }
        )
    }
}
