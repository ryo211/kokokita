//
//  MapPreview.swift
//  kokokita
//
//  Created by 橋本遼 on 2025/10/02.
//

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
            // ピン（Annotation）
            Annotation("ココキタ", coordinate: coordinate) {
                ZStack {
                    Image("kokokita_irodori_map")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 42, height: 42)
                }
            }
        }
        .overlay(alignment: .topLeading) {
            if showCoordinateOverlay {
                CoordinateBadge(lat: coordinate.latitude, lon: coordinate.longitude, decimals: decimals)
                    .padding(8)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                showMapAppSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "map")
                        .font(.callout)
                    Text("地図アプリで開く")
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
        .clipShape(RoundedRectangle(cornerRadius: AppConfig.mapCornerRadius))
        .confirmationDialog("地図アプリで開く", isPresented: $showMapAppSheet, titleVisibility: .visible) {
            Button("Apple Maps") {
                openInAppleMaps()
            }
            Button("Google Maps") {
                openInGoogleMaps()
            }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private func openInAppleMaps() {
        let latitude = coordinate.latitude
        let longitude = coordinate.longitude
        let urlString = "http://maps.apple.com/?ll=\(latitude),\(longitude)&q=ココキタ"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    private func openInGoogleMaps() {
        let latitude = coordinate.latitude
        let longitude = coordinate.longitude
        // Google Mapsアプリがインストールされている場合
        let googleMapsURL = "comgooglemaps://?q=\(latitude),\(longitude)&center=\(latitude),\(longitude)&zoom=15"
        // ブラウザで開く場合のフォールバック
        let webURL = "https://www.google.com/maps/search/?api=1&query=\(latitude),\(longitude)"

        if let url = URL(string: googleMapsURL), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let url = URL(string: webURL) {
            UIApplication.shared.open(url)
        }
    }
}

struct CoordinateBadge: View {
    let lat: Double
    let lon: Double
    let decimals: Int

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
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(radius: 1)
    }

    private func format(_ v: Double) -> String {
        String(format: "%.\(decimals)f", v)
    }
}
