import SwiftUI

struct GroupDetailView: View {
    let group: GroupTag
    var onFinish: (_ updated: GroupTag?, _ deleted: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var store = GroupListStore()
    @State private var name: String
    @State private var showDeleteConfirm = false

    init(group: GroupTag, onFinish: @escaping (_ updated: GroupTag?, _ deleted: Bool) -> Void) {
        self.group = group
        self.onFinish = onFinish
        _name = State(initialValue: group.name)
    }

    var body: some View {
        Form {
            Section { TextField("グループ名", text: $name)
                .submitLabel(.done)
                .onSubmit {
                    if TaxonomyValidator.isNotEmpty(name) {
                        save()
                    }
                }
            }
            Section {
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Label("このグループを削除", systemImage: "trash")
                }
            } footer: { Text("グループを削除しても、記録自体は削除されません。") }
        }
        .navigationTitle("グループ詳細")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") { save() }
                    .disabled(store.loading || !TaxonomyValidator.isNotEmpty(name))
            }
        }
        .alert("本当に削除しますか?", isPresented: $showDeleteConfirm) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) { delete() }
        } message: { Text("この操作は取り消せません。") }
        .alert("エラー", isPresented: Binding(get: { store.alert != nil }, set: { _ in store.alert = nil })) {
            Button("OK", role: .cancel) {}
        } message: { Text(store.alert ?? "") }
    }

    private func save() {
        if store.update(id: group.id, name: name) {
            onFinish(GroupTag(id: group.id, name: name), false)
            dismiss()
        }
    }

    private func delete() {
        if store.delete(id: group.id) {
            onFinish(nil, true)
            dismiss()
        }
    }
}
