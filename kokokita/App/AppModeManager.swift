import Foundation

// アプリモードを UserDefaults で管理するオブジェクト
final class AppModeManager: ObservableObject {
    /// UserDefaults キー: 現在のアプリモード
    private static let modeKey = "appMode"
    /// UserDefaults キー: モード選択画面を表示済みかどうか
    private static let hasSeenKey = "hasSeenModeSelection"

    private let defaults: UserDefaults

    /// 現在のアプリモード
    @Published private(set) var mode: AppMode

    /// モード選択画面を一度でも見たことがあるか
    @Published private(set) var hasSeenModeSelection: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let rawMode = defaults.string(forKey: Self.modeKey) ?? AppMode.record.rawValue
        self.mode = AppMode(rawValue: rawMode) ?? .record
        self.hasSeenModeSelection = defaults.bool(forKey: Self.hasSeenKey)
    }

    /// モードを切り替える
    func setMode(_ newMode: AppMode) {
        mode = newMode
        defaults.set(newMode.rawValue, forKey: Self.modeKey)
    }

    /// モード選択画面を表示済みとしてマーク
    func markModeSelectionSeen() {
        hasSeenModeSelection = true
        defaults.set(true, forKey: Self.hasSeenKey)
    }
}
