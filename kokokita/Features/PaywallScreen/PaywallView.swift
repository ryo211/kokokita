import SwiftUI
import StoreKit

/// Premiumプランのペイウォール画面
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = PaywallStore()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                    featuresSection
                    planPickerSection
                    ctaSection
                    legalSection
                }
                .padding(.bottom, 32)
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .alert(store.alertTitle ?? "", isPresented: .init(
                get: { store.alertTitle != nil },
                set: { if !$0 { store.clearAlert() } }
            )) {
                Button(L.Common.ok) {
                    if PremiumManager.shared.isPremium { dismiss() }
                    store.clearAlert()
                }
            } message: {
                if let msg = store.alertMessage { Text(msg) }
            }
            .task { await store.loadIfNeeded() }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            // 上からフェードするグラデーション背景
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.14),
                    Color.indigo.opacity(0.06),
                    Color(uiColor: .systemBackground).opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(maxWidth: .infinity)
            .frame(height: 260)

            VStack(spacing: 16) {
                // kokokita_prp 画像（アプリアイコン風カード）
                Image("kokokita_prp")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 130, height: 130)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .shadow(color: Color.blue.opacity(0.22), radius: 24, x: 0, y: 10)
                    .shadow(color: Color.black.opacity(0.08), radius: 6,  x: 0, y: 3)
                    .padding(.top, 36)

                VStack(spacing: 6) {
                    Text(L.Paywall.title)
                        .font(.title2.bold())

                    Text(L.Paywall.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - 機能リスト

    private var featuresSection: some View {
        VStack(spacing: 0) {
            FeatureRow(
                icon: "rectangle.slash.fill",
                iconColor: .blue,
                title: L.Paywall.featureNoAds,
                description: L.Paywall.featureNoAdsDesc
            )
            Divider().padding(.leading, 56)
            FeatureRow(
                icon: "books.vertical.fill",
                iconColor: .indigo,
                title: L.Paywall.featureMultiBook,
                description: L.Paywall.featureMultiBookDesc
            )
            Divider().padding(.leading, 56)
            FeatureRow(
                icon: "play.rectangle.fill",
                iconColor: .orange,
                title: L.Paywall.featureCourse,
                description: L.Paywall.featureCourseDesc
            )
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // MARK: - プラン選択

    private var planPickerSection: some View {
        VStack(spacing: 8) {
            if store.isLoading {
                ProgressView()
                    .frame(height: 120)
            } else if store.products.isEmpty {
                Text(L.Paywall.loadingProducts)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(height: 120)
            } else {
                ForEach(store.products, id: \.id) { product in
                    PlanCard(
                        product: product,
                        isSelected: store.selectedProductId == product.id,
                        onTap: { store.selectedProductId = product.id }
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // MARK: - CTAボタン

    private var ctaSection: some View {
        VStack(spacing: 12) {
            Button {
                Task { await store.purchase() }
            } label: {
                ZStack {
                    if store.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text(store.selectedProductId == PremiumProduct.lifetimeId
                             ? L.Paywall.ctaLifetime
                             : L.Paywall.ctaSubscribe)
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [.orange, .orange.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(store.isPurchasing || store.selectedProduct == nil)
            .padding(.horizontal, 16)

            Button {
                Task { await store.restore() }
            } label: {
                Text(L.Paywall.restore)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .disabled(store.isPurchasing)
        }
        .padding(.bottom, 16)
    }

    // MARK: - 法的リンク

    private var legalSection: some View {
        HStack(spacing: 16) {
            Link(L.Paywall.terms, destination: URL(string: "https://kokokita.app/terms")!)
            Text("•").foregroundStyle(.secondary)
            Link(L.Paywall.privacy, destination: URL(string: "https://kokokita.app/privacy")!)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

// MARK: - 機能行

private struct FeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - プランカード

private struct PlanCard: View {
    let product: Product
    let isSelected: Bool
    let onTap: () -> Void

    private var planLabel: String {
        switch product.id {
        case PremiumProduct.monthlyId:  return L.Paywall.monthly
        case PremiumProduct.lifetimeId: return L.Paywall.lifetime
        default:                        return product.displayName
        }
    }

    private var badge: String? {
        switch product.id {
        case PremiumProduct.lifetimeId: return L.Paywall.lifetimeBadge
        default:                        return nil
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 選択インジケーター
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .orange : .secondary)
                    .animation(.snappy, value: isSelected)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(planLabel)
                            .font(.subheadline.weight(.semibold))
                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.orange)
                                .clipShape(Capsule())
                        }
                    }
                    Text(product.displayPrice)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected
                          ? Color.orange.opacity(0.08)
                          : Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.orange : Color(.separator),
                                lineWidth: isSelected ? 1.5 : 0.5
                            )
                    )
            )
            .animation(.snappy, value: isSelected)
        }
        .buttonStyle(.plain)
    }
}
