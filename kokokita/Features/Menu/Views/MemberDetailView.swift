import SwiftUI

struct MemberDetailView: View {
    let member: MemberTag
    var onFinish: (_ updated: MemberTag?, _ deleted: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var store = MemberListStore()
    @State private var name: String
    @State private var showDeleteConfirm = false

    init(member: MemberTag, onFinish: @escaping (_ updated: MemberTag?, _ deleted: Bool) -> Void) {
        self.member = member
        self.onFinish = onFinish
        _name = State(initialValue: member.name)
    }

    var body: some View {
        Form {
            Section { TextField("メンバー名", text: $name)
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
                } label: { Label("このメンバーを削除", systemImage: "trash") }
            } footer: { Text("メンバーを削除しても、記録自体は削除されません。") }
        }
        .navigationTitle("メンバー詳細")
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
        if store.update(id: member.id, name: name) {
            onFinish(MemberTag(id: member.id, name: name), false)
            dismiss()
        }
    }

    private func delete() {
        if store.delete(id: member.id) {
            onFinish(nil, true)
            dismiss()
        }
    }
}
