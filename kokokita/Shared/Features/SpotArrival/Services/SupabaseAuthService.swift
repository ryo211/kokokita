import Foundation
import Security

/// Supabase匿名認証のセッションをKeychainで管理するサービス。
/// DefaultIntegrityServiceの署名鍵と同じく、Keychainに保存して再インストールをまたいで保持する。
/// ハンドルネーム設定時（P2）にSign in with Appleと連携すれば、同じuser_idを引き継げる
/// （doc/server-feature-design.md「ユーザー識別」参照）
struct SupabaseAuthService {
    struct Session: Codable {
        let userId: String
        let accessToken: String
        let refreshToken: String
        let expiresAt: Date
    }

    enum AuthError: Error {
        case notConfigured
        case invalidResponse
        case serverError(Int, String)
    }

    private let keychainAccount = "jp.kokokita.supabase.session"
    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    /// 有効なセッションを返す。無ければ匿名サインイン、期限切れ間近ならリフレッシュする。
    /// Supabase未設定の間はnilを返す
    func currentSession() async -> Session? {
        guard SupabaseConfig.isConfigured else { return nil }

        if let existing = loadSession() {
            if existing.expiresAt > Date().addingTimeInterval(60) {
                return existing
            }
            do {
                return try await refresh(existing.refreshToken)
            } catch {
                // リフレッシュ失敗（リフレッシュトークン失効等）は新規匿名サインインにフォールバック
                Logger.error("Supabaseセッションのリフレッシュに失敗", error: error)
            }
        }

        do {
            return try await signInAnonymously()
        } catch {
            Logger.error("Supabase匿名サインインに失敗", error: error)
            return nil
        }
    }

    // MARK: - サインイン・リフレッシュ

    private func signInAnonymously() async throws -> Session {
        try await request(path: "auth/v1/signup", body: Data("{}".utf8))
    }

    private func refresh(_ refreshToken: String) async throws -> Session {
        try await request(
            path: "auth/v1/token",
            queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")],
            body: try JSONEncoder().encode(["refresh_token": refreshToken])
        )
    }

    private func request(path: String, queryItems: [URLQueryItem] = [], body: Data) async throws -> Session {
        guard let baseURL = SupabaseConfig.projectURL, let anonKey = SupabaseConfig.anonKey else {
            throw AuthError.notConfigured
        }
        // appendingPathComponentにクエリ文字列を含めると "?" 等がパスの一部として扱われてしまうため、
        // URLComponentsでパスとクエリを分けて組み立てる
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw AuthError.invalidResponse
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else { throw AuthError.invalidResponse }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body

        let (data, response) = try await urlSession.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw AuthError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw AuthError.serverError(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        let newSession = Session(
            userId: decoded.user.id,
            accessToken: decoded.accessToken,
            refreshToken: decoded.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(decoded.expiresIn))
        )
        saveSession(newSession)
        return newSession
    }

    private struct TokenResponse: Decodable {
        let accessToken: String
        let refreshToken: String
        let expiresIn: Int
        let user: UserPayload

        struct UserPayload: Decodable {
            let id: String
        }

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
            case user
        }
    }

    // MARK: - Keychain

    private func saveSession(_ session: Session) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(baseQuery as CFDictionary)
        var attrs = baseQuery
        attrs[kSecValueData as String] = data
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attrs as CFDictionary, nil)
    }

    private func loadSession() -> Session? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(Session.self, from: data)
    }
}
