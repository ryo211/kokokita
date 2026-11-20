import Foundation

/// 到達記録をサーバー（Supabase）へ送信するクライアント。
/// Supabase未設定（SupabaseConfig.isConfigured == false）の間は常に失敗を返し、
/// キューには積んだまま保持する（SpotArrivalSyncServiceが次回再送する）。
/// サーバー側は doc/sql/phase1_schema.sql の record_spot_arrival RPC を使う想定。
/// doc/server-feature-design.md フェーズ1「到達時の『◯人目』表示」参照
struct SpotArrivalAPIClient {
    struct SendResult {
        /// そのスポット（place単位）での到達順位。RPCのレスポンスから得る
        let rank: Int?
    }

    enum APIError: Error {
        case notConfigured
        case invalidResponse
        case serverError(Int, String)
    }

    private let authService: SupabaseAuthService
    private let urlSession: URLSession

    init(
        authService: SupabaseAuthService = AppContainer.shared.supabaseAuthService,
        urlSession: URLSession = .shared
    ) {
        self.authService = authService
        self.urlSession = urlSession
    }

    func send(_ arrival: ResolvedSpotArrival) async -> Result<SendResult, Error> {
        guard SupabaseConfig.isConfigured else {
            Logger.info("到達記録送信スキップ（サーバー未設定）: course=\(arrival.courseRawId) spot=\(arrival.spotStringId)")
            return .failure(APIError.notConfigured)
        }
        guard let authSession = await authService.currentSession(),
              let baseURL = SupabaseConfig.projectURL,
              let anonKey = SupabaseConfig.anonKey else {
            Logger.error("到達記録送信スキップ（認証セッション取得失敗）", error: APIError.notConfigured)
            return .failure(APIError.notConfigured)
        }

        let payload: [String: Any] = [
            "p_id": arrival.id.uuidString,
            "p_visit_id": arrival.visitId.uuidString,
            "p_course_id": arrival.courseRawId,
            "p_spot_id": arrival.spotStringId,
            "p_arrived_at": ISO8601DateFormatter().string(from: arrival.arrivedAt),
            "p_distance_m": arrival.distanceMeters,
            "p_app_version": arrival.appVersion
        ]

        do {
            var req = URLRequest(url: baseURL.appendingPathComponent("rest/v1/rpc/record_spot_arrival"))
            req.httpMethod = "POST"
            req.setValue(anonKey, forHTTPHeaderField: "apikey")
            req.setValue("Bearer \(authSession.accessToken)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: payload)

            let (data, response) = try await urlSession.data(for: req)
            guard let http = response as? HTTPURLResponse else { return .failure(APIError.invalidResponse) }
            guard (200..<300).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                Logger.error("到達記録送信エラー（HTTP \(http.statusCode)）: \(body)")
                return .failure(APIError.serverError(http.statusCode, body))
            }

            // RPCは `returns table (rank bigint)` のため、PostgRESTはJSON配列で返す（例: [{"rank": 3}]）
            struct RankRow: Decodable { let rank: Int? }
            let rows = try JSONDecoder().decode([RankRow].self, from: data)
            return .success(SendResult(rank: rows.first?.rank))
        } catch {
            Logger.error("到達記録送信エラー", error: error)
            return .failure(error)
        }
    }

    /// 設定画面の「サーバーのデータを削除」から呼ぶ。本人の到達記録・閲覧イベントをサーバー側から削除する。
    /// アプリ内の記録（CoreData）には影響しない
    func deleteAllServerData() async -> Result<Void, Error> {
        guard SupabaseConfig.isConfigured else { return .failure(APIError.notConfigured) }
        guard let authSession = await authService.currentSession(),
              let baseURL = SupabaseConfig.projectURL,
              let anonKey = SupabaseConfig.anonKey else {
            return .failure(APIError.notConfigured)
        }

        do {
            var req = URLRequest(url: baseURL.appendingPathComponent("rest/v1/rpc/delete_my_data"))
            req.httpMethod = "POST"
            req.setValue(anonKey, forHTTPHeaderField: "apikey")
            req.setValue("Bearer \(authSession.accessToken)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = Data("{}".utf8)

            let (data, response) = try await urlSession.data(for: req)
            guard let http = response as? HTTPURLResponse else { return .failure(APIError.invalidResponse) }
            guard (200..<300).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                Logger.error("サーバーデータ削除エラー（HTTP \(http.statusCode)）: \(body)")
                return .failure(APIError.serverError(http.statusCode, body))
            }
            return .success(())
        } catch {
            Logger.error("サーバーデータ削除エラー", error: error)
            return .failure(error)
        }
    }
}
