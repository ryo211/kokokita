import Foundation

/// コースストアの Web API からデータを取得するサービス
final class CourseStoreService {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        baseURL: URL = URL(string: "https://kokokita-app.irodoriq.com/course/")!,
        session: URLSession = {
            // ローカルキャッシュを無視して常に最新データを取得する
            let config = URLSessionConfiguration.default
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            return URLSession(configuration: config)
        }()
    ) {
        self.baseURL = baseURL
        self.session = session
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        self.decoder = d
    }

    // MARK: - インデックス取得

    /// /store/index.json を取得してコースサマリー一覧を返す
    func fetchIndex() async throws -> StoreIndex {
        let url = baseURL.appendingPathComponent("store/index.json")
        let (data, response) = try await session.data(from: url)
        try validateResponse(response, url: url)
        return try decoder.decode(StoreIndex.self, from: data)
    }

    // MARK: - 個別コース取得

    /// jsonPath に基づいて個別コース JSON を取得し Course ドメインモデルに変換する
    /// - existingCourse: チェックイン状態などを引き継ぐための既存データ（任意）
    func fetchCourse(jsonPath: String, existingCourse: Course?) async throws -> Course {
        let url = baseURL.appendingPathComponent(jsonPath)
        let (data, response) = try await session.data(from: url)
        try validateResponse(response, url: url)
        let json = try decoder.decode(CourseJSONParser.CourseJSON.self, from: data)
        return CourseJSONParser.buildCourse(from: json, existing: existingCourse)
    }

    // MARK: - Private

    private func validateResponse(_ response: URLResponse, url: URL) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw CourseStoreError.httpError(statusCode: http.statusCode, url: url)
        }
    }
}

// MARK: - エラー定義

enum CourseStoreError: LocalizedError {
    case httpError(statusCode: Int, url: URL)

    var errorDescription: String? {
        switch self {
        case .httpError(let code, let url):
            return "通信エラー（HTTP \(code)）: \(url.lastPathComponent)"
        }
    }
}
