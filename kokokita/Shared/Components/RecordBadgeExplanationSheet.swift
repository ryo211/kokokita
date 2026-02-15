import SwiftUI

/// 記録バッジ説明シート
///
/// 証明付き記録と後付け記録の両方のバッジの意味を説明するシート。
struct RecordBadgeExplanationSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 証明付き記録の説明
                    badgeExplanationCard(
                        icon: "checkmark.seal.fill",
                        iconColor: .blue,
                        title: L.RecordBadge.verifiedTitle,
                        description: L.RecordBadge.verifiedDescription
                    )

                    // 後付け記録の説明
                    badgeExplanationCard(
                        icon: "wrench.adjustable.fill",
                        iconColor: .orange,
                        title: L.RecordBadge.manualTitle,
                        description: L.RecordBadge.manualDescription
                    )
                }
                .padding()
            }
            .navigationTitle(L.RecordBadge.explanationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L.Common.close) {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func badgeExplanationCard(
        icon: String,
        iconColor: Color,
        title: String,
        description: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(iconColor)

                Text(title)
                    .font(.headline)
            }

            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    RecordBadgeExplanationSheet()
}
