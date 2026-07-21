import Foundation
import StoreKit
import Observation

@Observable
@MainActor
final class PaywallStore {
    private(set) var isLoading = false
    private(set) var isPurchasing = false
    private(set) var alertTitle: String? = nil
    private(set) var alertMessage: String? = nil
    var selectedProductId: String = PremiumProduct.monthlyId

    var products: [Product] { PremiumManager.shared.products }

    var selectedProduct: Product? {
        products.first { $0.id == selectedProductId }
    }

    func clearAlert() {
        alertTitle = nil
        alertMessage = nil
    }

    // MARK: - 商品読み込み

    func loadIfNeeded() async {
        guard products.isEmpty else { return }
        isLoading = true
        await PremiumManager.shared.loadProducts()
        if let first = products.first {
            selectedProductId = first.id
        }
        isLoading = false
    }

    // MARK: - 購入

    func purchase() async -> Bool {
        guard let product = selectedProduct else { return false }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await PremiumManager.shared.purchase(product)
            return PremiumManager.shared.isPremium
        } catch {
            alertTitle = L.Paywall.purchaseError
            alertMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - 復元

    func restore() async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await PremiumManager.shared.restorePurchases()
            if PremiumManager.shared.isPremium {
                alertTitle = L.Paywall.restoreSuccess
                alertMessage = nil
            } else {
                alertTitle = L.Paywall.restoreFailed
                alertMessage = nil
            }
        } catch {
            alertTitle = L.Paywall.restoreFailed
            alertMessage = error.localizedDescription
        }
    }
}
