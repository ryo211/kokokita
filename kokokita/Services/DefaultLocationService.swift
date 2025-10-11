import Foundation
import CoreLocation

final class DefaultLocationService: NSObject, LocationService, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var cont: CheckedContinuation<(CLLocation, LocationSourceFlags), Error>?

    override init() {
        super.init()
        manager.desiredAccuracy = AppConfig.locationAccuracy
        manager.delegate = self
    }

    func requestOneShotLocation() async throws -> (CLLocation, LocationSourceFlags) {
        // 権限確認
        let status = CLLocationManager.authorizationStatus()
        if status == .notDetermined {
            Logger.info("Location permission not determined, requesting authorization")
            manager.requestWhenInUseAuthorization()
        }
        guard [.authorizedAlways, .authorizedWhenInUse].contains(CLLocationManager.authorizationStatus()) else {
            Logger.error("Location permission denied")
            throw NSError(domain: "Location", code: 1, userInfo: [NSLocalizedDescriptionKey: "位置情報の権限がありません"])
        }

        return try await withCheckedThrowingContinuation { (c: CheckedContinuation<(CLLocation, LocationSourceFlags), Error>) in
            self.cont = c
            self.manager.requestLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else {
            Logger.warning("Location update received but no locations available")
            return
        }
        let src = loc.sourceInformation
        let flags = LocationSourceFlags(
            isSimulatedBySoftware: src?.isSimulatedBySoftware,
            isProducedByAccessory: src?.isProducedByAccessory
        )
        Logger.success("Location acquired: \(loc.coordinate.latitude), \(loc.coordinate.longitude)")
        cont?.resume(returning: (loc, flags))
        cont = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Logger.error("Location manager failed", error: error)
        cont?.resume(throwing: error)
        cont = nil
    }
}
