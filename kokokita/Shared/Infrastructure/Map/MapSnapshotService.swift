import UIKit
@preconcurrency import MapKit
import SwiftUI

enum MapSnapshotService {

    static func makeSnapshot(
        center: CLLocationCoordinate2D,
        size: CGSize,
        spanMeters: CLLocationDistance = 300,
        showCoordinateBadge: Bool = true,
        decimals: Int = 4,
        badgeInset: CGFloat = 8
    ) async -> UIImage? {

        // 1) Options
        let region = MKCoordinateRegion(center: center,
                                        latitudinalMeters: spanMeters,
                                        longitudinalMeters: spanMeters)

        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = size
        options.scale = await MainActor.run { UIScreen.main.scale }
        options.showsBuildings = true
        options.pointOfInterestFilter = .includingAll

        // 2) snapshot（ハンドラ版でawait化）
        let snapshot = await withCheckedContinuation { (cont: CheckedContinuation<MKMapSnapshotter.Snapshot?, Never>) in
            let snapper = MKMapSnapshotter(options: options)
            snapper.start { snap, _ in cont.resume(returning: snap) }
        }
        guard let snap = snapshot else { return nil }

        // 3) ピン画像（MainActor）
        let pinImg: UIImage = await MainActor.run {
            makeMarkerViewImage()
        }

        // 4) バッジ画像（MainActor）
        let badgeImg: UIImage? = showCoordinateBadge ? await MainActor.run {
            makeCoordinateBadgeImage(lat: center.latitude, lon: center.longitude, decimals: decimals)
        } : nil

        // 5) 合成
        let fmt = UIGraphicsImageRendererFormat.default()
        fmt.scale = options.scale
        fmt.opaque = false

        let renderer = UIGraphicsImageRenderer(size: options.size, format: fmt)
        let composed = renderer.image { _ in
            // 地図
            snap.image.draw(at: .zero)

            // ピン
            let pt = snap.point(for: center)
            if pt.x.isFinite, pt.y.isFinite,
               pt.x >= 0, pt.y >= 0,
               pt.x <= options.size.width, pt.y <= options.size.height {
                // 先端を座標に合わせる
                let anchorY: CGFloat = 0.88
                let origin = CGPoint(x: pt.x - pinImg.size.width/2,
                                     y: pt.y - pinImg.size.height*anchorY)
                pinImg.draw(at: origin)
            }

            // バッジ（左上）
            if let b = badgeImg {
                let origin = CGPoint(x: badgeInset, y: badgeInset)
                b.draw(at: origin)
            }
        }
        return composed
    }

    // MARK: - Pins

    @MainActor
    private static func makePinSymbolImage() -> UIImage? {
        let cfg = UIImage.SymbolConfiguration(pointSize: 28, weight: .regular, scale: .medium)
        return UIImage(systemName: "mappin.and.ellipse", withConfiguration: cfg)?
            .withTintColor(.systemRed, renderingMode: .alwaysOriginal)
    }
//
//    @MainActor
//    private static func makeMarkerViewImage() -> UIImage {
//        let marker = MKMarkerAnnotationView(annotation: MKPointAnnotation(), reuseIdentifier: nil)
//        marker.markerTintColor = .systemRed
//        marker.glyphImage = UIImage(systemName: "mappin")
//        marker.prepareForDisplay()
//        let size = marker.intrinsicContentSize
//        marker.bounds = CGRect(origin: .zero, size: size)
//        marker.setNeedsLayout(); marker.layoutIfNeeded()
//
//        let r = UIGraphicsImageRenderer(size: size)
//        return r.image { ctx in marker.layer.render(in: ctx.cgContext) }
//    }
    
    // MARK: - Marker (ピン＋ラベル画像生成)

    @MainActor
    private static func makeMarkerViewImage() -> UIImage {
        // ピンとラベルを縦に配置
        let marker = VStack(spacing: 2) {
            Image("kokokita_irodori_map")
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)
//            Text("ココキタ")
//                .font(.caption2.weight(.semibold))
//                .foregroundColor(.primary)
//                .padding(.horizontal, 4)
//                .background(
//                    RoundedRectangle(cornerRadius: 4)
//                        .fill(Color(.systemBackground).opacity(0.8))
//                        .shadow(radius: 1, y: 1)
//                )
        }

        let renderer = ImageRenderer(content: marker)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage ?? UIImage()
    }


    // MARK: - Coordinate Badge（SwiftUI -> UIImage）

    @MainActor
    private static func makeCoordinateBadgeImage(lat: Double, lon: Double, decimals: Int) -> UIImage {
        let badge = CoordinateBadgeClassic(lat: lat, lon: lon, decimals: decimals)
        if #available(iOS 16.0, *) {
            let renderer = ImageRenderer(content: badge)
            renderer.scale = UIScreen.main.scale
            renderer.isOpaque = false
            return renderer.uiImage ?? UIImage()
        } else {
            let host = UIHostingController(rootView: badge)
            host.view.backgroundColor = .clear
            let size = host.sizeThatFits(in: CGSize(width: 500, height: 200))
            host.view.bounds = CGRect(origin: .zero, size: size)
            let r = UIGraphicsImageRenderer(size: size)
            return r.image { ctx in host.view.layer.render(in: ctx.cgContext) }
        }
    }
}

fileprivate struct CoordinateBadgeClassic: View {
    let lat: Double
    let lon: Double
    let decimals: Int

    private func format(_ v: Double) -> String {
        String(format: "%.\(decimals)f", v)
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "location.circle")
            Text("\(format(lat)), \(format(lon))")
                .font(.caption.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            Capsule().fill(Color(.systemBackground).opacity(0.7))
        )
        .shadow(color: Color.black.opacity(0.15), radius: 2, y: 1)
        .foregroundStyle(.primary)
    }
}
