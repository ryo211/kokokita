import Foundation
import FirebaseCrashlytics

/// アプリ全体で使用するロギングユーティリティ
enum Logger {

    // MARK: - Log Levels

    /// エラーレベルのログ（本番環境でも記録すべき重大な問題）
    static func error(
        _ message: String,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        let location = "[\(fileName):\(line)] \(function)"

        #if DEBUG
        print("❌ ERROR \(location)")
        print("   Message: \(message)")
        if let error = error {
            print("   Error: \(error.localizedDescription)")
            print("   Details: \(error)")
        }
        #endif

        // Firebase Crashlyticsに送信
        let crashlytics = Crashlytics.crashlytics()
        crashlytics.log("\(location) - \(message)")

        if let error = error {
            // NSErrorとして記録
            let nsError = error as NSError
            crashlytics.record(error: nsError)
        } else {
            // エラーオブジェクトがない場合、カスタムエラーを作成
            let customError = NSError(
                domain: "com.hashimoto.kokokita",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: message,
                    "location": location
                ]
            )
            crashlytics.record(error: customError)
        }
    }

    /// 警告レベルのログ（問題になる可能性があるが致命的ではない）
    static func warning(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        let location = "[\(fileName):\(line)] \(function)"

        #if DEBUG
        print("⚠️ WARNING \(location)")
        print("   Message: \(message)")
        #endif

        // Firebase Crashlyticsにログ送信（非致命的エラー）
        let crashlytics = Crashlytics.crashlytics()
        crashlytics.log("⚠️ WARNING \(location) - \(message)")
    }

    /// 情報レベルのログ（開発時のデバッグ用）
    static func info(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        let location = "[\(fileName):\(line)] \(function)"
        print("ℹ️ INFO \(location)")
        print("   Message: \(message)")
        #endif
    }

    /// デバッグレベルのログ（詳細な情報）
    static func debug(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        print("🔍 DEBUG [\(fileName):\(line)] \(message)")
        #endif
    }

    /// 成功メッセージ（重要な操作の成功）
    static func success(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        print("✅ SUCCESS [\(fileName):\(line)] \(message)")
        #endif
    }
}
