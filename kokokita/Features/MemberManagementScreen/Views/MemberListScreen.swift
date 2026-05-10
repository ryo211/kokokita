import SwiftUI

private enum TaxonomySortOrder {
    case newest // 新しい順（最新記録日）
    case count  // 多い順（記録件数）
}

struct MemberListScreen: View {
    @Binding var showCreate: Bool

    @State private var store = MemberListStore()
    @State private var newMemberName = ""
    @State private var sortOrder: TaxonomySortOrder = .newest

    private var sortedItems: [MemberTag] {
        switch sortOrder {
        case .newest:
            return store.items
        case .count:
            return store.items.sorted {
                let l = store.visitCounts[$0.id] ?? 0
                let r = store.visitCounts[$1.id] ?? 0
                return l != r ? l > r : $0.name.localizedCompare($1.name) == .orderedAscending
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            sortBar

            List {
                ForEach(sortedItems) { tag in
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
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tag.name)
                                if let date = store.lastVisitDates[tag.id] {
                                    Text(formatDate(date))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
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
                    ContentUnavailableView(L.MemberManagement.emptyMessage, systemImage: "person",
                        description: Text(L.MemberManagement.emptyDescription))
                }
            }
        }
        .task { await store.load() }
        .onChange(of: showCreate) { _, isShowing in
            if isShowing { newMemberName = "" }
        }
        .sheet(isPresented: $showCreate) {
            NavigationStack {
                Form {
                    Section { TextField(L.MemberManagement.namePlaceholder, text: $newMemberName)
                        .textInputAutocapitalization(.none)
                        .disableAutocorrection(true)
                        .submitLabel(.done)
                        .onSubmit {
                            if MemberValidator.isNotEmpty(newMemberName) { createMember() }
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

    // MARK: - Sort Bar

    private var sortBar: some View {
        HStack {
            Spacer()
            Menu {
                Picker(selection: $sortOrder, label: EmptyView()) {
                    Text(L.TaxonomyList.sortNewest)
                        .tag(TaxonomySortOrder.newest)
                    Text(L.TaxonomyList.sortCount)
                        .tag(TaxonomySortOrder.count)
                }
            } label: {
                HStack(spacing: 4) {
                    Text(sortOrder == .newest ? L.TaxonomyList.sortNewest : L.TaxonomyList.sortCount)
                        .font(.caption)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(.systemGray6), in: Capsule())
            }
            .padding(.trailing, 16)
            .padding(.vertical, 6)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Helpers

    private func createMember() {
        if store.create(name: newMemberName) { showCreate = false }
    }

    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale.current
        fmt.dateFormat = "y/M/d"
        return fmt.string(from: date)
    }
}
