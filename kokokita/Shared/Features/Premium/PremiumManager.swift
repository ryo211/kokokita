import Foundation
import StoreKit
import Observation

/// App Store課金状態を管理するシングルトン（StoreKit 2）
@Observable
@MainActor
final class PremiumManager {
    static let shared = PremiumManager()

    // MARK: - 公開プロパティ

    /// 最終的な課金状態（ビューから参照する唯一の窓口）
    var isPremium: Bool {
        #if DEBUG
        if let override = debugOverride {
            return override
        }
        #endif
        return _isPremium
    }

    /// 読み込み済みの商品一覧（ペイウォールで使用）
    private(set) var products: [Product] = []

    // MARK: - 内部状態

    /// StoreKit検証済み課金状態
    private var _isPremium: Bool = false

    #if DEBUG
    /// デバッグ用オーバーライド（nil = 実際の状態、true/false = 強制）
    var debugOverride: Bool? = nil {
        didSet { persistDebugOverride() }
    }
    #endif

    private let cacheKey            = "jp.kokokita.premium.isPremium"
    private let debugOverrideKey    = "jp.kokokita.debug.premiumOverride"
    private let debugOverrideEnabledKey = "jp.kokokita.debug.premiumOverrideEnabled"

    private var updateListenerTask: Task<Void, Never>?

    // MARK: - 初期化

    private init() {
        // オフライン時のために最後の検証結果をキャッシュから復元
        _isPremium = UserDefaults.standard.bool(forKey: cacheKey)

        #if DEBUG
        // デバッグオーバーライドを復元
        if UserDefaults.standard.bool(forKey: debugOverrideEnabledKey) {
            debugOverride = UserDefaults.standard.bool(forKey: debugOverrideKey)
        }
        #endif

        // バックグラウンドでトランザクション変化を監視
        updateListenerTask = startTransactionListener()
    }

    // MARK: - 商品取得

    func loadProducts() async {
        do {
            let fetched = try await Product.products(for: PremiumProduct.allProductIds)
            products = fetched.sorted { PremiumProduct.sortOrder($0.id) < PremiumProduct.sortOrder($1.id) }
        } catch {
            Logger.error("課金商品の取得失敗", error: error)
        }
    }

    // MARK: - 購入

    /// 商品を購入する。ユーザーキャンセル時は何もしない
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await refreshPremiumStatus()
            await transaction.finish()
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    // MARK: - 復元

    func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshPremiumStatus()
    }

    // MARK: - 状態更新

    func refreshPremiumStatus() async {
        var hasPremium = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               PremiumProduct.isPremiumProduct(id: tx.productID),
               !tx.isUpgraded {
                hasPremium = true
                break
            }
        }
        _isPremium = hasPremium
        UserDefaults.standard.set(hasPremium, forKey: cacheKey)
    }

    // MARK: - トランザクション監視

    private func startTransactionListener() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let tx) = result {
                    await self?.refreshPremiumStatus()
                    await tx.finish()
                }
            }
        }
    }

    // MARK: - 検証

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PremiumError.failedVerification
        case .verified(let value):
            return value
        }
    }

    // MARK: - デバッグ

    #if DEBUG
    private func persistDebugOverride() {
        if let override = debugOverride {
            UserDefaults.standard.set(override, forKey: debugOverrideKey)
            UserDefaults.standard.set(true, forKey: debugOverrideEnabledKey)
        } else {
            UserDefaults.standard.removeObject(forKey: debugOverrideKey)
            UserDefaults.standard.removeObject(forKey: debugOverrideEnabledKey)
        }
    }
    #endif
}

// MARK: - エラー

enum PremiumError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "購入の検証に失敗しました"
        }
    }
}
