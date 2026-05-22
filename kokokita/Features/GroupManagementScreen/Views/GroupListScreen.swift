import SwiftUI

private enum TaxonomySortOrder {
    case newest // 新しい順（最新記録日）
    case count  // 多い順（記録件数）
}

struct GroupListScreen: View {
    @Binding var showCreate: Bool

    @State private var store = GroupListStore()
    @State private var newGroupName = ""
    @State private var sortOrder: TaxonomySortOrder = .newest

    private var sortedItems: [GroupTag] {
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
                            VStack(alignment: .leading, spacing: 3) {
                                Text(tag.name)
                                if let range = store.dateRanges[tag.id] {
                                    Text(formatDateRange(range.earliest, range.latest))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let names = store.tripMembers[tag.id] {
                                    MemberTagRow(names: names)
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
                    ContentUnavailableView(L.GroupManagement.emptyMessage, systemImage: "airplane",
                        description: Text(L.GroupManagement.emptyDescription))
                }
            }
        }
        .task { await store.load() }
        .onChange(of: showCreate) { _, isShowing in
            if isShowing { newGroupName = "" }
        }
        .sheet(isPresented: $showCreate) {
            NavigationStack {
                Form {
                    Section { TextField(L.GroupManagement.namePlaceholder, text: $newGroupName)
                        .textInputAutocapitalization(.none)
                        .disableAutocorrection(true)
                        .submitLabel(.done)
                        .onSubmit {
                            if GroupValidator.isNotEmpty(newGroupName) { createGroup() }
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

    private func createGroup() {
        if store.create(name: newGroupName) { showCreate = false }
    }

    private func formatDateRange(_ earliest: Date, _ latest: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale.current
        fmt.dateFormat = "y/M/d"
        let start = fmt.string(from: earliest)
        let end = fmt.string(from: latest)
        return start == end ? start : "\(start) ~ \(end)"
    }
}

// メンバー名タグ一覧（横並び）
private struct MemberTagRow: View {
    let names: [String]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(names, id: \.self) { name in
                memberTag(name)
            }
        }
    }

    private func memberTag(_ name: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "person")
                .font(.system(size: 9, weight: .medium))
            Text(name)
                .font(.system(size: 11))
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color(.systemGray5)))
        .foregroundStyle(.secondary)
    }
}
