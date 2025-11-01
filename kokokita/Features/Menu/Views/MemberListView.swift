import SwiftUI

struct MemberListView: View {
    @State private var store = MemberListStore()
    @State private var showCreate = false
    @State private var newMemberName = ""

    var body: some View {
        List {
            ForEach(store.items) { tag in
                NavigationLink {
                    MemberDetailView(member: tag) { updated, deleted in
                        if deleted {
                            store.items.removeAll { $0.id == tag.id }
                        } else if let updated {
                            if let idx = store.items.firstIndex(where: { $0.id == tag.id }) {
                                store.items[idx] = updated
                            }
                        }
                    }
                } label: {
                    HStack { Image(systemName: "person"); Text(tag.name) }
                }
            }
        }
        .overlay {
            if store.loading {
                ProgressView().controlSize(.large)
            } else if store.items.isEmpty {
                ContentUnavailableView("メンバーはありません", systemImage: "person",
                    description: Text("右上の+から作成できます。"))
            }
        }
        .navigationTitle("メンバー")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.load() }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    newMemberName = ""
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("メンバーを新規作成")
            }
        }
        .sheet(isPresented: $showCreate) {
            NavigationStack {
                Form {
                    Section { TextField("メンバー名", text: $newMemberName)
                        .textInputAutocapitalization(.none)
                        .disableAutocorrection(true)
                        .submitLabel(.done)
                        .onSubmit {
                            if TaxonomyValidator.isNotEmpty(newMemberName) {
                                createMember()
                            }
                        }
                    }
                    Section {
                        Button("作成") { createMember() }
                            .disabled(!TaxonomyValidator.isNotEmpty(newMemberName))
                        Button("キャンセル", role: .cancel) { showCreate = false }
                    }
                }
                .navigationTitle("メンバー新規作成")
            }
        }
        .alert("エラー", isPresented: Binding(get: { store.alert != nil }, set: { _ in store.alert = nil })) {
            Button("OK", role: .cancel) {}
        } message: { Text(store.alert ?? "") }
    }

    private func createMember() {
        if store.create(name: newMemberName) {
            showCreate = false
        }
    }
}
