import Foundation
import Combine

/// サーバーへのメタ情報送信（到達記録・コース閲覧・お気に入り）に関する設定（UserDefaultsで永続化）。
/// デフォルトはtrue（新規インストールは自動的にオン）。匿名データのみを送信し、設定画面から
/// いつでもオフにできる「オプトアウト」方式を採用している（ウェルカム画面で事前に説明する）。
/// ユーザーが明示的にオン/オフを選んだ値は、キーが既に保存されている限り常に優先される
/// doc/server-feature-design.md フェーズ1「同意とオプトアウト」参照
final class MetaCollectionSettings: ObservableObject {
    static let shared = MetaCollectionSettings()

    private let defaults = UserDefaults.standard
    private let isConsentedKey = "metaCollection.isConsented"

    /// サーバーへの送信がオンかどうか。falseの間はローカルのキューには積むが、
    /// 実際のネットワーク送信は一切行わない
    @Published var isConsented: Bool {
        didSet { defaults.set(isConsented, forKey: isConsentedKey) }
    }

    private init() {
        // キーが未保存（初回起動）の場合のみデフォルトtrue。一度でも明示的に
        // 保存された値（オン/オフどちらも）があれば、その選択を常に尊重する
        if defaults.object(forKey: isConsentedKey) == nil {
            self.isConsented = true
        } else {
            self.isConsented = defaults.bool(forKey: isConsentedKey)
        }
    }
}
