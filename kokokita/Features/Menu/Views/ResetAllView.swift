import SwiftUI

struct ResetAllView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showConfirm = false
    @State private var alert: String?

    var body: some View {
        Form {
            Section {
                Button(role: .destructive) {
                    showConfirm = true
                } label: {
                    Label("全ての記録を削除", systemImage: "trash")
                }
            } footer: {
                Text("Visit（記録）と付随する詳細をすべて削除します。取り消しはできません。")
            }
        }
        .navigationTitle("初期化")
        .alert("本当に削除しますか？", isPresented: $showConfirm) {
            Button("キャンセル", role: .cancel) {}
            Button("削除する", role: .destructive) { performReset() }
        } message: {
            Text("「ココキタ」の全ての記録が端末から削除されます。")
        }
        .alert("エラー", isPresented: Binding(get: { alert != nil }, set: { _ in alert = nil })) {
            Button("OK", role: .cancel) {}
        } message: { Text(alert ?? "") }
    }

    private func performReset() {
        do {
            try AppContainer.shared.repo.deleteAllVisits()
            NotificationCenter.default.post(name: .visitsChanged, object: nil)
            dismiss()
        } catch {
            alert = error.localizedDescription
        }
    }
}
