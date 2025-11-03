import Foundation
import CoreLocation

/// 位置情報サービスのエラー
enum LocationServiceError: LocalizedError {
    case permissionDenied
    case timeout
    case other(Error)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "位置情報の権限がありません"
        case .timeout:
            return "位置情報の取得がタイムアウトしました"
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

    func requestOneShotLocation(
        accuracy: CLLocationAccuracy? = nil,
        timeout: TimeInterval = AppConfig.locationTimeout
    ) async throws -> (CLLocation, LocationSourceFlags) {
        // 精度設定（指定がなければデフォルト値を使用）
        if let accuracy = accuracy {
            manager.desiredAccuracy = accuracy
        } else {
            manager.desiredAccuracy = AppConfig.locationAccuracy
        }
        
        // 権限確認
        let status = manager.authorizationStatus

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

        // タイムアウト付き位置情報取得
        return try await withThrowingTaskGroup(of: (CLLocation, LocationSourceFlags).self) { group in
            // 位置情報取得タスク
            group.addTask {
                try await withCheckedThrowingContinuation { (c: CheckedContinuation<(CLLocation, LocationSourceFlags), Error>) in
                    self.cont = c
                    Logger.info("Starting location updates with accuracy: \(self.manager.desiredAccuracy)m...")
                    self.manager.startUpdatingLocation()
                }
            }
            
            // タイムアウトタスク
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                Logger.warning("Location request timed out after \(timeout) seconds")
                throw LocationServiceError.timeout
            }
            
            // 最初に完了したタスクの結果を返す
            guard let result = try await group.next() else {
                throw LocationServiceError.other(NSError(domain: "DefaultLocationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No result returned"]))
            }
            
            // 残りのタスクをキャンセルして位置情報更新を停止
            group.cancelAll()
            self.manager.stopUpdatingLocation()
            Logger.info("Location updates stopped")
            
            return result
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else {
            Logger.warning("Location update received but no locations available")
            return
        }
        
        // 精度チェック：desiredAccuracyを満たしていれば即座に返す
        // horizontalAccuracyが負の値の場合は無効な測定値
        if loc.horizontalAccuracy > 0 && 
           loc.horizontalAccuracy <= manager.desiredAccuracy {
            
            let src = loc.sourceInformation
            let flags = LocationSourceFlags(
                isSimulatedBySoftware: src?.isSimulatedBySoftware,
                isProducedByAccessory: src?.isProducedByAccessory
            )
            
            Logger.success("Location acquired: \(loc.coordinate.latitude), \(loc.coordinate.longitude), accuracy: \(loc.horizontalAccuracy)m")
            
            manager.stopUpdatingLocation()
            cont?.resume(returning: (loc, flags))
            cont = nil
        } else {
            // 精度が不十分な場合は待機
            let accuracyStatus = loc.horizontalAccuracy <= 0 ? "invalid" : "\(loc.horizontalAccuracy)m"
            Logger.debug("Waiting for better accuracy: current \(accuracyStatus), desired \(manager.desiredAccuracy)m")
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Logger.error("Location manager failed", error: error)
        manager.stopUpdatingLocation()
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
