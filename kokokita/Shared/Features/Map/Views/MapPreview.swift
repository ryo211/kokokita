import SwiftUI
import MapKit
import CoreLocation

struct MapPreview: View {
    /// 「地図アプリで開く」ボタンの見た目
    enum OpenMapButtonStyle {
        /// 既存: アイコン+テキストのカプセル型
        case capsule
        /// アイコンのみの小さな丸ボタン
        case icon
    }

    let coordinate: CLLocationCoordinate2D
    var radius: CLLocationDistance = AppConfig.mapDisplayRadius
    var showCoordinateOverlay: Bool = true
    var decimals: Int = AppConfig.coordinateDecimals
    var markerImageName: String = "kokokita_irodori_blue_for_map"
    var markerLabelColor: Color = .accentColor
    /// カード自体の角丸。既定は他画面と揃えたAppConfig.mapCornerRadius
    var cornerRadius: CGFloat = AppConfig.mapCornerRadius
    /// ピンの下にパルスするリングを表示するか
    var pulsing: Bool = false
    var openMapButtonStyle: OpenMapButtonStyle = .capsule

    @State private var position: MapCameraPosition
    @State private var showMapAppSheet = false
    @State private var isPulsing = false

    init(lat: Double, lon: Double, radius: CLLocationDistance = AppConfig.mapDisplayRadius,
         showCoordinateOverlay: Bool = true, decimals: Int = AppConfig.coordinateDecimals,
         markerImageName: String = "kokokita_irodori_blue_for_map",
         markerLabelColor: Color = .accentColor,
         cornerRadius: CGFloat = AppConfig.mapCornerRadius,
         pulsing: Bool = false,
         openMapButtonStyle: OpenMapButtonStyle = .capsule) {
        let center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let region = MKCoordinateRegion(center: center,
                                        latitudinalMeters: radius * 2,
                                        longitudinalMeters: radius * 2)
        self.coordinate = center
        self.radius = radius
        self.showCoordinateOverlay = showCoordinateOverlay
        self.decimals = decimals
        self.markerImageName = markerImageName
        self.markerLabelColor = markerLabelColor
        self.cornerRadius = cornerRadius
        self.pulsing = pulsing
        self.openMapButtonStyle = openMapButtonStyle
        _position = State(initialValue: .region(region))
    }

    var body: some View {
        Map(position: $position, interactionModes: [.pan, .zoom, .rotate]) {
            mapAnnotation
        }
        .overlay(alignment: .topLeading) {
            coordinateBadgeOverlay
        }
        .overlay(alignment: .bottomTrailing) {
            openMapButton
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .confirmationDialog(L.Map.openInApp, isPresented: $showMapAppSheet, titleVisibility: .visible) {
            mapAppSelectionButtons
        }
    }

    // MARK: - View Components

    @MapContentBuilder
    private var mapAnnotation: some MapContent {
        Annotation("", coordinate: coordinate) {
            VStack(spacing: 2) {
                Text(L.App.name)
                    .font(.caption.bold())
                    .foregroundColor(markerLabelColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white)
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)

                ZStack {
                    if pulsing {
                        Circle()
                            .fill(markerLabelColor.opacity(0.18))
                            .frame(width: 34, height: 34)
                            .scaleEffect(isPulsing ? 1.6 : 0.4)
                            .opacity(isPulsing ? 0 : 0.8)
                            .onAppear {
                                withAnimation(.easeOut(duration: 2.2).repeatForever(autoreverses: false)) {
                                    isPulsing = true
                                }
                            }
                    }
                    Image(markerImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 42, height: 42)
                }
            }
        }
    }

    @ViewBuilder
    private var coordinateBadgeOverlay: some View {
        if showCoordinateOverlay {
            CoordinateBadge(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                decimals: decimals
            )
            .padding(8)
        }
    }

    @ViewBuilder
    private var openMapButton: some View {
        switch openMapButtonStyle {
        case .capsule:
            Button {
                showMapAppSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "map")
                        .font(.callout)
                    Text(L.Map.openInApp)
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .shadow(radius: 2)
            }
            .buttonStyle(.plain)
            .padding(8)
        case .icon:
            Button {
                showMapAppSheet = true
            } label: {
                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 32, height: 32)
                    .background(.ultraThinMaterial, in: Circle())
                    .shadow(radius: 2)
            }
            .buttonStyle(.plain)
            .padding(10)
        }
    }

    @ViewBuilder
    private var mapAppSelectionButtons: some View {
        Button("Apple Maps") {
            openInAppleMaps()
        }
        Button("Google Maps") {
            openInGoogleMaps()
        }
        Button(L.Common.cancel, role: .cancel) {}
    }

    // MARK: - Actions

    private func openInAppleMaps() {
        guard let url = MapURLBuilder.buildAppleMapsURL(coordinate: coordinate) else { return }
        UIApplication.shared.open(url)
    }

    private func openInGoogleMaps() {
        // アプリURL優先、失敗したらWeb URL
        if let appURL = MapURLBuilder.buildGoogleMapsAppURL(coordinate: coordinate),
           UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else if let webURL = MapURLBuilder.buildGoogleMapsWebURL(coordinate: coordinate) {
            UIApplication.shared.open(webURL)
        }
    }
}
