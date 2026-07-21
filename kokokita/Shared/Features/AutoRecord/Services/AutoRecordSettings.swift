import Foundation
import Combine

/// 自動記録機能の設定（UserDefaults で永続化）
final class AutoRecordSettings: ObservableObject {
    static let shared = AutoRecordSettings()

    private let defaults = UserDefaults.standard
    private let isEnabledKey = "autoRecord.isEnabled"

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: isEnabledKey) }
    }

    private init() {
        self.isEnabled = defaults.bool(forKey: "autoRecord.isEnabled")
    }
}
