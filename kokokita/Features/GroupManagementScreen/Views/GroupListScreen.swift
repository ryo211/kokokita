import SwiftUI

struct GroupListScreen: View {
    @State private var store = GroupListStore()
    @State private var showCreate = false
    @State private var newGroupName = ""

    var body: some View {
        List {
            ForEach(store.items) { tag in
                NavigationLink {
                    GroupDetailView(group: tag) { updated, deleted in
                        if deleted {
                            store.items.removeAll { $0.id == tag.id }
                        } else if let updated {
                            if let idx = store.items.firstIndex(where: { $0.id == tag.id }) {
                                store.items[idx] = updated
                            }
                        }
                    }
                } label: {
                    HStack { Image(systemName: "folder"); Text(tag.name) }
                }
            }
        }
        .overlay {
            if store.loading {
                ProgressView().controlSize(.large)
            } else if store.items.isEmpty {
                ContentUnavailableView("グループはありません", systemImage: "folder",
                    description: Text("右上の+から作成できます。"))
            }
        }
        .navigationTitle("グループ")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.load() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newGroupName = ""
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("グループを新規作成")
            }
        }
        .sheet(isPresented: $showCreate) {
            NavigationStack {
                Form {
                    Section { TextField("グループ名", text: $newGroupName)
                        .textInputAutocapitalization(.none)
                        .disableAutocorrection(true)
                        .submitLabel(.done)
                        .onSubmit {
                            if GroupValidator.isNotEmpty(newGroupName) {
                                createGroup()
                            }
                        }
                    }
                    Section {
                        Button("作成") { createGroup() }
                            .disabled(!GroupValidator.isNotEmpty(newGroupName))
                        Button("キャンセル", role: .cancel) { showCreate = false }
                    }
                }
                .navigationTitle("グループ新規作成")
            }
        }
        .alert("エラー", isPresented: Binding(get: { store.alert != nil }, set: { _ in store.alert = nil })) {
            Button("OK", role: .cancel) {}
        } message: { Text(store.alert ?? "") }
    }

    private func createGroup() {
        if store.create(name: newGroupName) {
            showCreate = false
        }
    }
}
