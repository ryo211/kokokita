import SwiftUI
import GoogleMobileAds

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // v11 以降：引数なしでOK
        MobileAds.shared.start()

        // （任意）デバッグ中の安全運用：テスト端末ID
        // MobileAds.shared.requestConfiguration.testDeviceIdentifiers = ["YOUR-TEST-DEVICE-ID"]

        return true
    }
}
