//
//  LocationGeocodingService.swift
//  kokokita
//
//  Created by Claude on 2025/10/11.
//

import Foundation
import CoreLocation
import Contacts

/// 位置情報取得と住所逆引きを組み合わせたサービス
@MainActor
final class LocationGeocodingService {

    // MARK: - Dependencies

    private let locationService: LocationService
    private let geocoder: CLGeocoder

    // MARK: - Initialization

    init(locationService: LocationService, geocoder: CLGeocoder = CLGeocoder()) {
        self.locationService = locationService
        self.geocoder = geocoder
    }

    // MARK: - Location Result

    struct LocationResult {
        let timestamp: Date
        let latitude: Double
        let longitude: Double
        let accuracy: Double?
        let address: String?
        let flags: LocationSourceFlags
    }

    // MARK: - Request Location with Address

    /// 位置情報を取得し、住所も逆引きする
    func requestLocationWithAddress() async throws -> LocationResult {
        // 位置情報を取得
        let (location, flags) = try await locationService.requestOneShotLocation()

        // シミュレーション／アクセサリチェック
        if flags.isSimulatedBySoftware == true || flags.isProducedByAccessory == true {
            throw LocationGeocodingError.simulatedOrAccessory
        }

        // 住所を逆引き（失敗しても続行）
        let address = await reverseGeocode(location)

        return LocationResult(
            timestamp: Date(),
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            accuracy: location.horizontalAccuracy,
            address: address,
            flags: flags
        )
    }

    // MARK: - Reverse Geocoding

    /// 住所を逆引きする（内部用）
    private func reverseGeocode(_ location: CLLocation) async -> String? {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                return formatAddress(placemark)
            }
            return nil
        } catch {
            Logger.warning("Geocoding failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// 住所をフォーマットする
    private func formatAddress(_ placemark: CLPlacemark) -> String {
        if let postal = placemark.postalAddress {
            let formatter = CNPostalAddressFormatter()
            return formatter.string(from: postal).replacingOccurrences(of: "\n", with: " ")
        }
        return [placemark.name, placemark.locality, placemark.administrativeArea, placemark.country]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}

// MARK: - Errors

enum LocationGeocodingError: LocalizedError {
    case simulatedOrAccessory

    var errorDescription: String? {
        switch self {
        case .simulatedOrAccessory:
            return L.Error.locationSimulated
        }
    }
}
