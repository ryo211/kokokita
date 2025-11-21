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
            Section { TextField(L.GroupManagement.namePlaceholder, text: $name)
                .submitLabel(.done)
                .onSubmit {
                    if GroupValidator.isNotEmpty(name) {
                        save()
                    }
                }
            }
            Section {
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Label(L.GroupManagement.deleteConfirm, systemImage: "trash")
                }
            } footer: { Text(L.GroupManagement.deleteFooter) }
        }
        .navigationTitle(L.GroupManagement.detailTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L.Common.save) { save() }
                    .disabled(store.loading || !GroupValidator.isNotEmpty(name))
            }
        }
        .alert(L.GroupManagement.deleteReallyConfirm, isPresented: $showDeleteConfirm) {
            Button(L.Common.cancel, role: .cancel) {}
            Button(L.Common.delete, role: .destructive) { delete() }
        } message: { Text(L.GroupManagement.deleteIrreversible) }
        .alert(L.Common.error, isPresented: Binding(get: { store.alert != nil }, set: { _ in store.alert = nil })) {
            Button(L.Common.ok, role: .cancel) {}
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
