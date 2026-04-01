import Foundation
import Observation

#if DEBUG
/// デバッグモード専用の設定管理（@Observable マクロ使用、iOS 17+）
@Observable
final class DebugSettings {
    static let shared = DebugSettings()

    private let defaults = UserDefaults.standard
    private let adDisplayKey = "jp.kokokita.debug.adDisplay"

    private init() {
        // UserDefaultsから初期値をロード
        isAdDisplayEnabled = defaults.object(forKey: adDisplayKey) as? Bool ?? false
    }

    /// 広告表示のON/OFF（デバッグモード専用）
    var isAdDisplayEnabled: Bool = false {
        didSet {
            defaults.set(isAdDisplayEnabled, forKey: adDisplayKey)
        }
    }
}
#endif
