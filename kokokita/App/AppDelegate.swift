import SwiftUI
import GoogleMobileAds
import FirebaseCore
import FirebaseCrashlytics

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // Firebase初期化
        FirebaseApp.configure()

        // Crashlyticsの設定
        #if DEBUG
        // デバッグビルドではCrashlyticsのデータ収集を無効化（オプション）
        // Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
        #endif

        // AdMob初期化（v11 以降：引数なしでOK）
        MobileAds.shared.start()

        // （任意）デバッグ中の安全運用：テスト端末ID
        // MobileAds.shared.requestConfiguration.testDeviceIdentifiers = ["YOUR-TEST-DEVICE-ID"]

        return true
    }
}
