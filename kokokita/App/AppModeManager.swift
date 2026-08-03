import Foundation
import Observation

// アプリモードを UserDefaults で管理するオブジェクト
@Observable
final class AppModeManager {
    /// UserDefaults キー: 現在のアプリモード
    private static let modeKey = "appMode"
    /// UserDefaults キー: ウェルカム画面を表示済みかどうか
    private static let hasSeenKey = "hasSeenWelcome"

    private let defaults: UserDefaults

    /// 現在のアプリモード
    private(set) var mode: AppMode

    /// ウェルカム画面を一度でも見たことがあるか
    private(set) var hasSeenWelcome: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let rawMode = defaults.string(forKey: Self.modeKey) ?? AppMode.pilgrimage.rawValue
        self.mode = AppMode(rawValue: rawMode) ?? .pilgrimage
        self.hasSeenWelcome = defaults.bool(forKey: Self.hasSeenKey)
    }

    /// モードを切り替える
    func setMode(_ newMode: AppMode) {
        mode = newMode
        defaults.set(newMode.rawValue, forKey: Self.modeKey)
    }

    /// ウェルカム画面を表示済みとしてマーク
    func markWelcomeSeen() {
        hasSeenWelcome = true
        defaults.set(true, forKey: Self.hasSeenKey)
    }
}
