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
            Section { TextField(L.MemberManagement.namePlaceholder, text: $name)
                .submitLabel(.done)
                .onSubmit {
                    if MemberValidator.isNotEmpty(name) {
                        save()
                    }
                }
            }
            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: { Label(L.MemberManagement.deleteConfirm, systemImage: "trash") }
            } footer: { Text(L.MemberManagement.deleteFooter) }
        }
        .navigationTitle(L.MemberManagement.detailTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L.Common.save) { save() }
                    .disabled(store.loading || !MemberValidator.isNotEmpty(name))
            }
        }
        .alert(L.MemberManagement.deleteReallyConfirm, isPresented: $showDeleteConfirm) {
            Button(L.Common.cancel, role: .cancel) {}
            Button(L.Common.delete, role: .destructive) { delete() }
        } message: { Text(L.MemberManagement.deleteIrreversible) }
        .alert(L.Common.error, isPresented: Binding(get: { store.alert != nil }, set: { _ in store.alert = nil })) {
            Button(L.Common.ok, role: .cancel) {}
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
