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

    /// 巡礼モード：レビュー誘導を表示するまでのコース詳細閲覧回数
    private let courseDetailTriggerCount = 3

    /// UserDefaultsのキー
    private enum Keys {
        static let recordCount = "appReview.recordCount"
        static let hasRequestedReview = "appReview.hasRequestedReview"
        static let lastReviewRequestVersion = "appReview.lastReviewRequestVersion"
        static let courseDetailOpenCount = "appReview.courseDetailOpenCount"
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
        guard shouldRequestReview(triggerCount: reviewTriggerCount, countKey: Keys.recordCount) else { return }

        Task {
            try? await Task.sleep(for: .milliseconds(500))
            requestReview()
        }
    }

    /// コース詳細画面が開かれた時に呼ばれる（巡礼モード）
    /// 条件を満たしていればレビュー誘導を表示
    func courseDetailViewOpened() {
        let currentCount = UserDefaults.standard.integer(forKey: Keys.courseDetailOpenCount)
        UserDefaults.standard.set(currentCount + 1, forKey: Keys.courseDetailOpenCount)

        guard shouldRequestReview(triggerCount: courseDetailTriggerCount, countKey: Keys.courseDetailOpenCount) else { return }

        Task {
            try? await Task.sleep(for: .milliseconds(500))
            requestReview()
        }
    }

    // MARK: - Private Methods

    /// レビュー誘導を表示すべきかどうか
    private func shouldRequestReview(triggerCount: Int, countKey: String) -> Bool {
        let count = UserDefaults.standard.integer(forKey: countKey)
        guard count >= triggerCount else { return false }

        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
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
        UserDefaults.standard.removeObject(forKey: Keys.courseDetailOpenCount)
        Logger.info("App review state reset for debug")
    }

    /// デバッグ用：現在の記録数を取得
    var currentRecordCount: Int {
        UserDefaults.standard.integer(forKey: Keys.recordCount)
    }
    #endif
}
