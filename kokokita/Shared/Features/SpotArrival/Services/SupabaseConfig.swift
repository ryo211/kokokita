import Foundation

/// Supabaseプロジェクトの接続情報。
/// Info.plist の SUPABASE_URL / SUPABASE_ANON_KEY に実際の値を設定するまでは
/// isConfigured が false になり、関連するネットワーク機能は送信をスキップする。
/// anonKeyはRLSで保護される公開可能な鍵のため、既存のGADApplicationIdentifierと同様に
/// Info.plistへ直接記載する運用でよい（service_role keyは絶対にクライアントへ含めないこと）
enum SupabaseConfig {
    static var projectURL: URL? {
        guard let s = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              !s.isEmpty, let url = URL(string: s) else { return nil }
        return url
    }

    static var anonKey: String? {
        guard let s = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !s.isEmpty else { return nil }
        return s
    }

    static var isConfigured: Bool { projectURL != nil && anonKey != nil }
}
