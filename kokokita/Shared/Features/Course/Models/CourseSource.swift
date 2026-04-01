import Foundation

// コースの提供元
enum CourseSource: String {
    /// アプリ内蔵コース
    case bundled = "bundled"
    /// ユーザー作成コース
    case user = "user"
    /// ダウンロードコース（Phase 2）
    case downloaded = "downloaded"
}
