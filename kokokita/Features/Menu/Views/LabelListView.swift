import SwiftUI

struct LabelListView: View {
    @State private var store = LabelListStore()
    @State private var showCreate = false
    @State private var newLabelName = ""

    var body: some View {
        List {
            ForEach(store.items) { tag in
                NavigationLink {
                    LabelDetailView(label: tag) { updated, deleted in
                        if deleted {
                            store.items.removeAll { $0.id == tag.id }
                        } else if let updated {
                            if let idx = store.items.firstIndex(where: { $0.id == tag.id }) {
                                store.items[idx] = updated
                            }
                        }
                    }
                } label: {
                    HStack { Image(systemName: "tag"); Text(tag.name) }
                }
            }
        }
        .overlay {
            if store.loading {
                ProgressView().controlSize(.large)
            } else if store.items.isEmpty {
                ContentUnavailableView("ラベルはありません", systemImage: "tag",
                    description: Text("右上の+から作成できます。"))
            }
        }
        .navigationTitle("ラベル")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.load() }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    newLabelName = ""
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("ラベルを新規作成")
            }
        }
        .sheet(isPresented: $showCreate) {
            NavigationStack {
                Form {
                    Section { TextField("ラベル名", text: $newLabelName)
                        .textInputAutocapitalization(.none)
                        .disableAutocorrection(true)
                        .submitLabel(.done)
                        .onSubmit {
                            if TaxonomyValidator.isNotEmpty(newLabelName) {
                                createLabel()
                            }
                        }
                    }
                    Section {
                        Button("作成") { createLabel() }
                            .disabled(!TaxonomyValidator.isNotEmpty(newLabelName))
                        Button("キャンセル", role: .cancel) { showCreate = false }
                    }
                }
                .navigationTitle("ラベル新規作成")
            }
        }
        .alert("エラー", isPresented: Binding(get: { store.alert != nil }, set: { _ in store.alert = nil })) {
            Button("OK", role: .cancel) {}
        } message: { Text(store.alert ?? "") }
    }

    private func createLabel() {
        if store.create(name: newLabelName) {
            showCreate = false
        }
    }
}
