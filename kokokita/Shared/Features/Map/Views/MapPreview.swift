import SwiftUI
import MapKit
import CoreLocation

struct MapPreview: View {
    let coordinate: CLLocationCoordinate2D
    var radius: CLLocationDistance = AppConfig.mapDisplayRadius
    var showCoordinateOverlay: Bool = true
    var decimals: Int = AppConfig.coordinateDecimals

    @State private var position: MapCameraPosition
    @State private var showMapAppSheet = false

    init(lat: Double, lon: Double, radius: CLLocationDistance = AppConfig.mapDisplayRadius,
         showCoordinateOverlay: Bool = true, decimals: Int = AppConfig.coordinateDecimals) {
        let center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let region = MKCoordinateRegion(center: center,
                                        latitudinalMeters: radius * 2,
                                        longitudinalMeters: radius * 2)
        self.coordinate = center
        self.radius = radius
        self.showCoordinateOverlay = showCoordinateOverlay
        self.decimals = decimals
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
        .clipShape(RoundedRectangle(cornerRadius: AppConfig.mapCornerRadius))
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
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white)
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)

                Image("kokokita_irodori_blue")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 42)
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

    private var openMapButton: some View {
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
