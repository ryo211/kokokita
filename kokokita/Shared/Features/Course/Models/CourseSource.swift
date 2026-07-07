import Foundation

// コースの提供元
enum CourseSource: String {
    /// アプリ内蔵コース（廃止・既存データとの後方互換のためケースは残す）
    case bundled = "bundled"
    /// ユーザー作成コース
    case user = "user"
    /// サーバーから自動同期されたコース
    case downloaded = "downloaded"
}
