import Foundation
import StoreKit
import SwiftUI

/// アプリレビュー誘導サービス
///
/// 記録数をカウントし、指定回数に達したらApp Storeレビュー誘導を表示する。
@MainActor
final class AppReviewService {
    static let shared = AppReviewService()

    /// レビュー誘導を表示するまでの記録数
    private let reviewTriggerCount = 5

    /// UserDefaultsのキー
    private enum Keys {
        static let recordCount = "appReview.recordCount"
        static let hasRequestedReview = "appReview.hasRequestedReview"
        static let lastReviewRequestVersion = "appReview.lastReviewRequestVersion"
    }

    private init() {}

    // MARK: - Public Methods

    /// アプリ起動時に既存の記録数で初期化（既存ユーザー対応）
    /// UserDefaultsに値がない場合のみ、既存の記録数をセットする
    func initializeIfNeeded(existingRecordCount: Int) {
        // 既にカウントが存在する場合は何もしない
        if UserDefaults.standard.object(forKey: Keys.recordCount) != nil {
            return
        }

        // 既存の記録数をセット
        UserDefaults.standard.set(existingRecordCount, forKey: Keys.recordCount)
        Logger.info("App review: initialized with existing record count: \(existingRecordCount)")
    }

    /// 記録が作成されたことを通知
    func recordCreated() {
        let currentCount = UserDefaults.standard.integer(forKey: Keys.recordCount)
        UserDefaults.standard.set(currentCount + 1, forKey: Keys.recordCount)
    }

    /// 記録シートが閉じた時に呼ばれる
    /// 条件を満たしていればレビュー誘導を表示
    func onRecordSheetDismissed() {
        guard shouldRequestReview() else { return }

        // 少し遅延を入れてからレビュー誘導を表示（UX改善）
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            requestReview()
        }
    }

    // MARK: - Private Methods

    /// レビュー誘導を表示すべきかどうか
    private func shouldRequestReview() -> Bool {
        let recordCount = UserDefaults.standard.integer(forKey: Keys.recordCount)

        // 記録数がトリガー数に達しているか
        guard recordCount >= reviewTriggerCount else { return false }

        // 現在のアプリバージョン
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

        // このバージョンで既にリクエスト済みか
        let lastRequestedVersion = UserDefaults.standard.string(forKey: Keys.lastReviewRequestVersion)
        if lastRequestedVersion == currentVersion {
            return false
        }

        return true
    }

    /// レビュー誘導を表示
    private func requestReview() {
        // 現在のバージョンを記録
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        UserDefaults.standard.set(currentVersion, forKey: Keys.lastReviewRequestVersion)
        UserDefaults.standard.set(true, forKey: Keys.hasRequestedReview)

        // レビュー誘導を表示（iOS 18+ の新API を優先使用）
        if #available(iOS 18.0, *) {
            Task { @MainActor in
                if let scene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first {
                    AppStore.requestReview(in: scene)
                }
            }
        } else {
            if let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first {
                SKStoreReviewController.requestReview(in: scene)
            }
        }

        Logger.info("App review requested at record count: \(UserDefaults.standard.integer(forKey: Keys.recordCount))")
    }

    // MARK: - Debug

    #if DEBUG
    /// デバッグ用：カウントをリセット
    func resetForDebug() {
        UserDefaults.standard.removeObject(forKey: Keys.recordCount)
        UserDefaults.standard.removeObject(forKey: Keys.hasRequestedReview)
        UserDefaults.standard.removeObject(forKey: Keys.lastReviewRequestVersion)
        Logger.info("App review state reset for debug")
    }

    /// デバッグ用：現在の記録数を取得
    var currentRecordCount: Int {
        UserDefaults.standard.integer(forKey: Keys.recordCount)
    }
    #endif
}
