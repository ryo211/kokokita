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
    var radius: CLLocationDistance = 5000
    var showCoordinateOverlay: Bool = true
    var decimals: Int = 5

    @State private var position: MapCameraPosition


    init(lat: Double, lon: Double, radius: CLLocationDistance = 5000,
         showCoordinateOverlay: Bool = true, decimals: Int = 5) {
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
            Annotation("ココキタ！", coordinate: coordinate) {
                ZStack {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.tint)
                }
            }
        }
        .overlay(alignment: .topLeading) {
            if showCoordinateOverlay {
                CoordinateBadge(lat: coordinate.latitude, lon: coordinate.longitude, decimals: decimals)
                    .padding(8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
