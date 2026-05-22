import SwiftUI

private enum TaxonomySortOrder {
    case newest // 新しい順（最新記録日）
    case count  // 多い順（記録件数）
}

struct LabelListScreen: View {
    @Binding var showCreate: Bool

    @State private var store = LabelListStore()
    @State private var newLabelName = ""
    @State private var newLabelColorId: String? = nil
    @State private var sortOrder: TaxonomySortOrder = .newest

    private var sortedItems: [LabelTag] {
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
                            Circle()
                                .fill(LabelColorId.from(tag.colorId)?.color ?? ChipKind.defaultTint)
                                .frame(width: 10, height: 10)
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
                    ContentUnavailableView(L.LabelManagement.emptyMessage, systemImage: "tag",
                        description: Text(L.LabelManagement.emptyDescription))
                }
            }
        }
        .task { await store.load() }
        .onChange(of: showCreate) { _, isShowing in
            if isShowing {
                newLabelName = ""
                newLabelColorId = nil
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
                        LabelColorPicker(selectedColorId: newLabelColorId) { colorId in
                            newLabelColorId = colorId
                        }
                    } header: {
                        Text(L.LabelColor.sectionTitle)
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

    private func createLabel() {
        if store.create(name: newLabelName, colorId: newLabelColorId) {
            showCreate = false
        }
    }

    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale.current
        fmt.dateFormat = "y/M/d"
        return fmt.string(from: date)
    }
}
