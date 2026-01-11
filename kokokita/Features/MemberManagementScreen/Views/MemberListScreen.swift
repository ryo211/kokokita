import SwiftUI

struct MemberListScreen: View {
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
                    HStack {
                        Image(systemName: "person")
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
        .overlay {
            if store.loading {
                ProgressView().controlSize(.large)
            } else if store.items.isEmpty {
                ContentUnavailableView(L.MemberManagement.emptyMessage, systemImage: "person",
                    description: Text(L.MemberManagement.emptyDescription))
            }
        }
        .navigationTitle(L.MemberManagement.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.load() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newMemberName = ""
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(L.MemberManagement.createAccessibility)
            }
        }
        .sheet(isPresented: $showCreate) {
            NavigationStack {
                Form {
                    Section { TextField(L.MemberManagement.namePlaceholder, text: $newMemberName)
                        .textInputAutocapitalization(.none)
                        .disableAutocorrection(true)
                        .submitLabel(.done)
                        .onSubmit {
                            if MemberValidator.isNotEmpty(newMemberName) {
                                createMember()
                            }
                        }
                    }
                    Section {
                        Button(L.Common.create) { createMember() }
                            .disabled(!MemberValidator.isNotEmpty(newMemberName))
                        Button(L.Common.cancel, role: .cancel) { showCreate = false }
                    }
                }
                .navigationTitle(L.MemberManagement.createTitle)
            }
        }
        .alert(L.Common.error, isPresented: Binding(get: { store.alert != nil }, set: { _ in store.alert = nil })) {
            Button(L.Common.ok, role: .cancel) {}
        } message: { Text(store.alert ?? "") }
    }

    private func createMember() {
        if store.create(name: newMemberName) {
            showCreate = false
        }
    }
}
