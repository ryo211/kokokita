import Foundation
import CoreLocation

final class DefaultLocationService: NSObject, LocationService, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var cont: CheckedContinuation<(CLLocation, LocationSourceFlags), Error>?

    override init() {
        super.init()
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.delegate = self
    }

    func requestOneShotLocation() async throws -> (CLLocation, LocationSourceFlags) {
        // 権限確認
        let status = CLLocationManager.authorizationStatus()
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        guard [.authorizedAlways, .authorizedWhenInUse].contains(CLLocationManager.authorizationStatus()) else {
            throw NSError(domain: "Location", code: 1, userInfo: [NSLocalizedDescriptionKey: "位置情報の権限がありません"])
        }

        return try await withCheckedThrowingContinuation { (c: CheckedContinuation<(CLLocation, LocationSourceFlags), Error>) in
            self.cont = c
            self.manager.requestLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let src = loc.sourceInformation
        let flags = LocationSourceFlags(
            isSimulatedBySoftware: src?.isSimulatedBySoftware,
            isProducedByAccessory: src?.isProducedByAccessory
        )
        cont?.resume(returning: (loc, flags))
        cont = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        cont?.resume(throwing: error)
        cont = nil
    }
}
