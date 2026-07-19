import Foundation
import Observation

#if DEBUG
/// デバッグモード専用の設定管理（@Observable マクロ使用、iOS 17+）
@Observable
@MainActor
final class DebugSettings {
    static let shared = DebugSettings()

    private let defaults = UserDefaults.standard
    private let adDisplayKey = "jp.kokokita.debug.adDisplay"

    private init() {
        isAdDisplayEnabled = defaults.object(forKey: adDisplayKey) as? Bool ?? false
    }

    /// 広告表示のON/OFF（デバッグモード専用）
    var isAdDisplayEnabled: Bool = false {
        didSet {
            defaults.set(isAdDisplayEnabled, forKey: adDisplayKey)
        }
    }

    /// Premium状態のオーバーライド
    /// - nil: 実際のStoreKit課金状態を使用
    /// - true: 強制Premium（有料機能をすべて開放）
    /// - false: 強制フリー（課金済みでも有料機能をロック）
    var premiumOverride: Bool? {
        get { PremiumManager.shared.debugOverride }
        set { PremiumManager.shared.debugOverride = newValue }
    }
}
#endif
