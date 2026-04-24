import SwiftUI

struct RecognitionRangeInfoButton: View {
    let title: String
    let message: String

    @State private var showSheet = false

    var body: some View {
        Button {
            showSheet = true
        } label: {
            Image(systemName: "info.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSheet) {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Spacer()
                    Button(L.Common.close) {
                        showSheet = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .presentationDetents([.height(220)])
            .presentationDragIndicator(.visible)
        }
        .accessibilityLabel(title)
    }
}
