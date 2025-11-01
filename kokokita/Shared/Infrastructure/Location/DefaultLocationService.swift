import Foundation
import CoreLocation

/// 位置情報サービスのエラー
enum LocationServiceError: LocalizedError {
    case permissionDenied
    case other(Error)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "位置情報の権限がありません"
        case .other(let error):
            return error.localizedDescription
        }
    }
}

final class DefaultLocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var cont: CheckedContinuation<(CLLocation, LocationSourceFlags), Error>?
    private var authCont: CheckedContinuation<Bool, Never>?

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

            // 権限ダイアログの結果を待つ
            let granted = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
                self.authCont = c
            }

            if !granted {
                Logger.error("Location permission denied by user")
                throw LocationServiceError.permissionDenied
            }
        } else if ![.authorizedAlways, .authorizedWhenInUse].contains(status) {
            Logger.error("Location permission denied")
            throw LocationServiceError.permissionDenied
        }

        do {
            return try await withCheckedThrowingContinuation { (c: CheckedContinuation<(CLLocation, LocationSourceFlags), Error>) in
                self.cont = c
                self.manager.requestLocation()
            }
        } catch {
            throw LocationServiceError.other(error)
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

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Logger.info("Location authorization changed to: \(status.rawValue)")

        // 権限ダイアログの結果を返す
        if let authCont = authCont {
            let granted = [.authorizedAlways, .authorizedWhenInUse].contains(status)
            authCont.resume(returning: granted)
            self.authCont = nil
        }
    }
}
