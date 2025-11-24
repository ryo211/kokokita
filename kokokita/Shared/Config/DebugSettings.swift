import Foundation
import Combine

#if DEBUG
/// デバッグモード専用の設定管理
final class DebugSettings: ObservableObject {
    static let shared = DebugSettings()

    private let defaults = UserDefaults.standard
    private let adDisplayKey = "jp.kokokita.debug.adDisplay"

    private init() {
        // 初期値をロード
        _isAdDisplayEnabled = Published(initialValue: defaults.object(forKey: adDisplayKey) as? Bool ?? false)
    }

    /// 広告表示のON/OFF（デバッグモード専用）
    @Published var isAdDisplayEnabled: Bool = false {
        didSet {
            defaults.set(isAdDisplayEnabled, forKey: adDisplayKey)
        }
    }
}
#endif
