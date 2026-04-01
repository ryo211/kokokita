import Foundation

/// コースストア index.json のトップレベルモデル
struct StoreIndex: Decodable {
    let schemaVersion: Int
    let courses: [StoreCourseSummary]
}

/// コースストア一覧の各コースサマリー（index.json の要素）
/// 個別コース JSON を取得せずとも一覧表示できる情報を保持する
struct StoreCourseSummary: Identifiable, Decodable {
    let id: String
    let title: String
    let summary: String?
    let categories: [String]
    let version: Int
    let coverImageUrl: String?
    let spotCount: Int
    /// ベース URL からの相対パス（例: "courses/world_heritage_japan_001.json"）
    let jsonPath: String
    let updatedAt: Date?

    /// カテゴリ文字列を CourseCategory に変換したもの
    var parsedCategories: [CourseCategory] {
        categories.compactMap { CourseCategory(rawValue: $0) }
    }
}

/// 各コースのダウンロード状態
enum CourseDownloadStatus: Equatable {
    /// 未ダウンロード
    case notDownloaded
    /// ダウンロード中
    case downloading
    /// ダウンロード済み（同バージョン）
    case downloaded
    /// 更新あり（ローカルバージョン < リモートバージョン）
    case updateAvailable(remoteVersion: Int)
}
