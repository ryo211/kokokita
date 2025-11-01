import SwiftUI

struct LabelDetailView: View {
    let label: LabelTag
    var onFinish: (_ updated: LabelTag?, _ deleted: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var store = LabelListStore()
    @State private var name: String
    @State private var showDeleteConfirm = false

    init(label: LabelTag, onFinish: @escaping (_ updated: LabelTag?, _ deleted: Bool) -> Void) {
        self.label = label
        self.onFinish = onFinish
        _name = State(initialValue: label.name)
    }

    var body: some View {
        Form {
            Section { TextField("ラベル名", text: $name)
                .submitLabel(.done)
                .onSubmit {
                    if TaxonomyValidator.isNotEmpty(name) {
                        save()
                    }
                }
            }
            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: { Label("このラベルを削除", systemImage: "trash") }
            } footer: { Text("ラベルを削除しても、記録自体は削除されません。") }
        }
        .navigationTitle("ラベル詳細")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") { save() }
                    .disabled(store.loading || !TaxonomyValidator.isNotEmpty(name))
            }
        }
        .alert("本当に削除しますか？", isPresented: $showDeleteConfirm) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) { delete() }
        } message: { Text("この操作は取り消せません。") }
        .alert("エラー", isPresented: Binding(get: { store.alert != nil }, set: { _ in store.alert = nil })) {
            Button("OK", role: .cancel) {}
        } message: { Text(store.alert ?? "") }
    }

    private func save() {
        if store.update(id: label.id, name: name) {
            onFinish(LabelTag(id: label.id, name: name), false)
            dismiss()
        }
    }

    private func delete() {
        if store.delete(id: label.id) {
            onFinish(nil, true)
            dismiss()
        }
    }
}
