import SwiftUI

/// 後付け記録機能の説明シート
struct ManualEntryInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    infoRow(
                        systemImage: "clock.badge.questionmark",
                        text: L.ManualEntry.infoSheetPoint1
                    )
                    infoRow(
                        systemImage: "calendar.badge.clock",
                        text: L.ManualEntry.infoSheetPoint2
                    )
                    infoRow(
                        systemImage: "exclamationmark.triangle",
                        text: L.ManualEntry.infoSheetPoint3
                    )
                }
                .padding()
            }
            .navigationTitle(L.ManualEntry.infoSheetTitle)
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

    private func infoRow(systemImage: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .padding(.top, 2)

            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    ManualEntryInfoSheet()
}
