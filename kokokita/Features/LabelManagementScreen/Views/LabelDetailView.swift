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
            Section { TextField(L.LabelManagement.namePlaceholder, text: $name)
                .submitLabel(.done)
                .onSubmit {
                    if LabelValidator.isNotEmpty(name) {
                        save()
                    }
                }
            }
            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: { Label(L.LabelManagement.deleteConfirm, systemImage: "trash") }
            } footer: { Text(L.LabelManagement.deleteFooter) }
        }
        .navigationTitle(L.LabelManagement.detailTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L.Common.save) { save() }
                    .disabled(store.loading || !LabelValidator.isNotEmpty(name))
            }
        }
        .alert(L.LabelManagement.deleteReallyConfirm, isPresented: $showDeleteConfirm) {
            Button(L.Common.cancel, role: .cancel) {}
            Button(L.Common.delete, role: .destructive) { delete() }
        } message: { Text(L.LabelManagement.deleteIrreversible) }
        .alert(L.Common.error, isPresented: Binding(get: { store.alert != nil }, set: { _ in store.alert = nil })) {
            Button(L.Common.ok, role: .cancel) {}
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
