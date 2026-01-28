import SwiftUI

struct GroupListScreen: View {
    @Binding var showCreate: Bool

    @State private var store = GroupListStore()
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
                    HStack {
                        Text(tag.name)
                        Spacer()
                        if let count = store.visitCounts[tag.id] {
                            Text("\(count)\(L.Home.itemsCount)")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if store.loading {
                ProgressView().controlSize(.large)
            } else if store.items.isEmpty {
                ContentUnavailableView(L.GroupManagement.emptyMessage, systemImage: "folder",
                    description: Text(L.GroupManagement.emptyDescription))
            }
        }
        .task { await store.load() }
        .onChange(of: showCreate) { _, isShowing in
            if isShowing {
                newGroupName = ""
            }
        }
        .sheet(isPresented: $showCreate) {
            NavigationStack {
                Form {
                    Section { TextField(L.GroupManagement.namePlaceholder, text: $newGroupName)
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
                        Button(L.Common.create) { createGroup() }
                            .disabled(!GroupValidator.isNotEmpty(newGroupName))
                        Button(L.Common.cancel, role: .cancel) { showCreate = false }
                    }
                }
                .navigationTitle(L.GroupManagement.createTitle)
            }
        }
        .alert(L.Common.error, isPresented: Binding(get: { store.alert != nil }, set: { _ in store.alert = nil })) {
            Button(L.Common.ok, role: .cancel) {}
        } message: { Text(store.alert ?? "") }
    }

    private func createGroup() {
        if store.create(name: newGroupName) {
            showCreate = false
        }
    }
}
