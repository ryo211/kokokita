import Foundation
import Combine

/// サーバーへのメタ情報送信（到達記録・コース閲覧）に関する同意設定（UserDefaultsで永続化）。
/// デフォルトは false（未同意）。同意画面UIが実装されるまでは常にfalseのままにし、
/// 実装後に同意画面からこのフラグをtrueにする運用を想定している。
/// doc/server-feature-design.md フェーズ1「同意とオプトアウト」参照
final class MetaCollectionSettings: ObservableObject {
    static let shared = MetaCollectionSettings()

    private let defaults = UserDefaults.standard
    private let isConsentedKey = "metaCollection.isConsented"

    /// サーバーへの送信に同意済みかどうか。falseの間はローカルのキューには積むが、
    /// 実際のネットワーク送信は一切行わない
    @Published var isConsented: Bool {
        didSet { defaults.set(isConsented, forKey: isConsentedKey) }
    }

    private init() {
        self.isConsented = defaults.bool(forKey: isConsentedKey)
    }
}
