import SwiftUI

struct LabelListScreen: View {
    @Binding var showCreate: Bool

    @State private var store = LabelListStore()
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
                ContentUnavailableView(L.LabelManagement.emptyMessage, systemImage: "tag",
                    description: Text(L.LabelManagement.emptyDescription))
            }
        }
        .task { await store.load() }
        .onChange(of: showCreate) { _, isShowing in
            if isShowing {
                newLabelName = ""
            }
        }
        .sheet(isPresented: $showCreate) {
            NavigationStack {
                Form {
                    Section { TextField(L.LabelManagement.namePlaceholder, text: $newLabelName)
                        .textInputAutocapitalization(.none)
                        .disableAutocorrection(true)
                        .submitLabel(.done)
                        .onSubmit {
                            if LabelValidator.isNotEmpty(newLabelName) {
                                createLabel()
                            }
                        }
                    }
                    Section {
                        Button(L.Common.create) { createLabel() }
                            .disabled(!LabelValidator.isNotEmpty(newLabelName))
                        Button(L.Common.cancel, role: .cancel) { showCreate = false }
                    }
                }
                .navigationTitle(L.LabelManagement.createTitle)
            }
        }
        .alert(L.Common.error, isPresented: Binding(get: { store.alert != nil }, set: { _ in store.alert = nil })) {
            Button(L.Common.ok, role: .cancel) {}
        } message: { Text(store.alert ?? "") }
    }

    private func createLabel() {
        if store.create(name: newLabelName) {
            showCreate = false
        }
    }
}
