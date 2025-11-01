import Foundation
import CoreLocation
import Contacts

/// 位置情報取得と住所逆引きを組み合わせたサービス
@MainActor
struct LocationGeocodingService {

    // MARK: - Dependencies

    private let locationService: DefaultLocationService
    private let geocoder: CLGeocoder

    // MARK: - Initialization

    init(locationService: DefaultLocationService, geocoder: CLGeocoder = CLGeocoder()) {
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

    /// 位置情報を取得し、住所も逆引きする（タイムアウト付き）
    /// - Parameter onAddressResolved: バックグラウンドで住所が取得できた時のコールバック
    func requestLocationWithAddress(
        onAddressResolved: @escaping (String) -> Void = { _ in }
    ) async throws -> LocationResult {
        // 位置情報を取得
        let (location, flags) = try await locationService.requestOneShotLocation()

        // シミュレーション／アクセサリチェック
        if flags.isSimulatedBySoftware == true || flags.isProducedByAccessory == true {
            throw LocationGeocodingError.simulatedOrAccessory
        }

        // 住所を逆引き（2秒タイムアウト）
        let address = await reverseGeocodeWithTimeout(
            location,
            timeout: 2.0,
            onDelayedResult: onAddressResolved
        )

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

    /// タイムアウト付きで住所を逆引きする
    /// - Parameters:
    ///   - location: 位置情報
    ///   - timeout: タイムアウト時間（秒）
    ///   - onDelayedResult: タイムアウト後に住所が取得できた場合のコールバック
    /// - Returns: タイムアウト内に取得できた住所（タイムアウトした場合はnil）
    private func reverseGeocodeWithTimeout(
        _ location: CLLocation,
        timeout: TimeInterval,
        onDelayedResult: @escaping (String) -> Void
    ) async -> String? {
        // タイムアウトとジオコーディングを競争させる
        let result = await withTaskGroup(of: String?.self) { group in
            // ジオコーディングタスク
            group.addTask {
                await self.reverseGeocode(location)
            }

            // タイムアウトタスク
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                return nil
            }

            // 最初に完了したタスクの結果を取得
            if let firstResult = await group.next() {
                // 残りのタスクをキャンセル
                group.cancelAll()
                return firstResult
            }
            return nil
        }

        // タイムアウトした場合、バックグラウンドで住所取得を継続
        if result == nil {
            Task {
                if let address = await self.reverseGeocode(location) {
                    await MainActor.run {
                        onDelayedResult(address)
                    }
                }
            }
        }

        return result
    }

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
