import Foundation
import Combine

/// 自動記録機能の設定（UserDefaults で永続化）
final class AutoRecordSettings: ObservableObject {
    static let shared = AutoRecordSettings()

    private let defaults = UserDefaults.standard
    private let isEnabledKey = "autoRecord.isEnabled"
    private let hasSeenIntroKey = "autoRecord.hasSeenIntro"
    private let hasAttemptedAlwaysUpgradeKey = "autoRecord.hasAttemptedAlwaysUpgrade"

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: isEnabledKey) }
    }

    /// 自動記録機能の初回説明シート（AutoRecordIntroSheet）を表示済みかどうか
    @Published var hasSeenIntro: Bool {
        didSet { defaults.set(hasSeenIntro, forKey: hasSeenIntroKey) }
    }

    /// Always許可への昇格ダイアログ（requestAlwaysAuthorization）を一度でも試みたか。
    /// iOSはこのダイアログを端末ごとに一度しか表示しないため、2回目以降はOSに問い合わせず
    /// 設定アプリへの案内を直接出す判断に使う
    @Published var hasAttemptedAlwaysUpgrade: Bool {
        didSet { defaults.set(hasAttemptedAlwaysUpgrade, forKey: hasAttemptedAlwaysUpgradeKey) }
    }

    private init() {
        self.isEnabled = defaults.bool(forKey: "autoRecord.isEnabled")
        self.hasSeenIntro = defaults.bool(forKey: "autoRecord.hasSeenIntro")
        self.hasAttemptedAlwaysUpgrade = defaults.bool(forKey: "autoRecord.hasAttemptedAlwaysUpgrade")
    }
}
