import SwiftUI
import MapKit

// タクソノミー詳細画面用のコンパクト地図ビュー
// nameSection の直下に配置し、関連記録のピンを表示する（高さ：画面の約3/10）
struct TaxonomyDetailMapView: View {
    let visits: [VisitAggregate]
    let labelMap: [UUID: String]
    let labelColorMap: [String: Color]
    @Binding var focusedVisitId: UUID?

    @State private var cameraPosition: MapCameraPosition = .automatic

    // 選択されたピンが最前面に描画されるよう末尾に移動
    private var sortedVisits: [VisitAggregate] {
        visits.sorted { v1, _ in v1.id != focusedVisitId }
    }

    var body: some View {
        Map(position: $cameraPosition) {
            ForEach(sortedVisits) { agg in
                if agg.visit.latitude != 0 || agg.visit.longitude != 0 {
                    let isSelected = focusedVisitId == agg.id
                    Annotation("", coordinate: CLLocationCoordinate2D(
                        latitude: agg.visit.latitude,
                        longitude: agg.visit.longitude
                    )) {
                        MapPinView(isSelected: isSelected, pinColor: firstLabelColor(for: agg))
                            .onTapGesture {
                                focusedVisitId = agg.id
                            }
                    }
                    .annotationTitles(.hidden)
                }
            }
        }
        .mapStyle(.standard)
        .onAppear {
            updateCameraPosition()
        }
        .onChange(of: visits) {
            updateCameraPosition()
        }
    }

    // 先頭ラベル色を取得（VisitMapView と同じロジック）
    private func firstLabelColor(for agg: VisitAggregate) -> Color? {
        let names = agg.details.labelIds
            .compactMap { labelMap[$0] }
            .sorted { $0.localizedCompare($1) == .orderedAscending }
        guard let firstName = names.first else { return nil }
        return labelColorMap[firstName]
    }

    // 全ピンが収まるようにカメラ位置を更新
    private func updateCameraPosition() {
        let coords = visits.compactMap { agg -> CLLocationCoordinate2D? in
            guard agg.visit.latitude != 0 || agg.visit.longitude != 0 else { return nil }
            return CLLocationCoordinate2D(latitude: agg.visit.latitude, longitude: agg.visit.longitude)
        }
        guard !coords.isEmpty else {
            cameraPosition = .automatic
            return
        }
        if coords.count == 1 {
            cameraPosition = .region(MKCoordinateRegion(
                center: coords[0],
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            ))
        } else {
            let rect = coords.reduce(MKMapRect.null) { rect, coord in
                let point = MKMapPoint(coord)
                return rect.union(MKMapRect(x: point.x, y: point.y, width: 0, height: 0))
            }
            cameraPosition = .rect(rect.insetBy(dx: -rect.size.width * 0.18, dy: -rect.size.height * 0.18))
        }
    }
}
