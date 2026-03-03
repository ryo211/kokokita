// アプリの動作モードを表す列挙型
enum AppMode: String, CaseIterable {
    /// 巡礼モード: コース機能を使って聖地巡礼などを楽しむモード
    case pilgrimage
    /// 記録モード: 従来の訪問記録モード
    case record
}
