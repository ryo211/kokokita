import SwiftUI

// コースストアシート（モーダル表示）
struct CourseStoreSheet: View {
    private let store: CourseStoreSheetStore
    @Environment(\.dismiss) private var dismiss

    init(store: CourseStoreSheetStore) {
        self.store = store
    }

    var body: some View {
        NavigationStack {
            CourseStoreListView(store: store)
                .navigationTitle(L.CourseStore.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(L.Common.close) { dismiss() }
                    }
                }
        }
        .task {
            await store.loadIndex()
            store.applyDefaultFilter()
        }
        .onDisappear {
            store.markVisited()
        }
        .alert(L.Common.error, isPresented: Bindable(store).showError) {
            Button(L.Common.ok) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}

// MARK: - コースストア一覧

private struct CourseStoreListView: View {
    @Bindable var store: CourseStoreSheetStore
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 検索中はフィルターバーを非表示
            if store.searchText.isEmpty {
                // ダウンロード状態フィルターバー
                HStack(spacing: 8) {
                    ForEach(StoreDownloadFilter.allCases, id: \.self) { filter in
                        CourseStoreFilterChip(
                            label: filter.label,
                            isSelected: store.selectedDownloadFilter == filter
                        ) {
                            store.selectedDownloadFilter = filter
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()

                // カテゴリフィルターバー
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CourseStoreFilterChip(
                            label: L.Home.filterAll,
                            isSelected: store.selectedCategory == nil
                        ) {
                            store.selectedCategory = nil
                        }
                        ForEach(CourseCategory.allCases, id: \.rawValue) { category in
                            CourseStoreFilterChip(
                                icon: category.iconName,
                                label: category.displayName,
                                isSelected: store.selectedCategory == category
                            ) {
                                store.selectedCategory = store.selectedCategory == category ? nil : category
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                Divider()
            }

            if store.isLoadingIndex {
                Spacer()
                ProgressView()
                Spacer()
            } else if store.filteredCourses.isEmpty {
                ContentUnavailableView(
                    store.searchText.isEmpty ? L.CourseStore.emptyTitle : L.CourseStore.emptyTitle,
                    systemImage: store.searchText.isEmpty ? "arrow.down.circle" : "magnifyingglass",
                    description: Text(store.searchText.isEmpty ? L.CourseStore.emptyDescription : "「\(store.searchText)」に一致するコースはありません")
                )
            } else {
                List {
                    ForEach(store.filteredCourses) { summary in
                        CourseStoreRowView(
                            summary: summary,
                            status: store.downloadStatuses[summary.id] ?? .notDownloaded,
                            isNew: store.isNew(summary)
                        ) {
                            store.download(summary: summary)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .safeAreaInset(edge: .bottom) {
            CourseSearchBar(searchText: $store.searchText, isFocused: $isSearchFocused)
        }
    }
}

// MARK: - 検索バー（画面下部固定・CourseListView でも共用）

struct CourseSearchBar: View {
    @Binding var searchText: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 15))

            TextField(L.CourseStore.searchPlaceholder, text: $searchText)
                .focused(isFocused)
                .font(.body)
                .submitLabel(.search)

            Button {
                searchText = ""
                isFocused.wrappedValue = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(searchText.isEmpty ? Color.secondary.opacity(0.4) : Color.secondary)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

// MARK: - コース行

private struct CourseStoreRowView: View {
    let summary: StoreCourseSummary
    let status: CourseDownloadStatus
    var isNew: Bool = false
    let onAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // サムネイル
            Group {
                if let urlStr = summary.coverImageUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill()
                        } else {
                            thumbnailPlaceholder
                        }
                    }
                } else {
                    thumbnailPlaceholder
                }
            }
            .frame(width: 96, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // テキスト
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(summary.title)
                        .font(.body.weight(.semibold))
                        .lineLimit(2)
                    if isNew {
                        Text(L.Course.newBadge)
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red, in: Capsule())
                    }
                }

                if !summary.parsedCategories.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(summary.parsedCategories, id: \.rawValue) { category in
                            HStack(spacing: 3) {
                                Image(systemName: category.iconName)
                                Text(category.displayName)
                            }
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.indigo)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.indigo.opacity(0.1), in: Capsule())
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(L.CourseStore.spotCount(summary.spotCount))
                    if let updatedAt = summary.updatedAt {
                        Text(L.Course.updatedAt(updatedAt.formatted(.dateTime.year().month().day())))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // アクションボタン
            actionButton
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var actionButton: some View {
        switch status {
        case .notDownloaded:
            Button(L.CourseStore.downloadButton, action: onAction)
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .controlSize(.small)

        case .downloading:
            ProgressView()
                .controlSize(.small)
                .frame(width: 60)

        case .downloaded:
            Text(L.CourseStore.downloadedBadge)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.secondary.opacity(0.12), in: Capsule())

        case .updateAvailable:
            Button(L.CourseStore.updateButton, action: onAction)
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.small)
        }
    }

    private var thumbnailPlaceholder: some View {
        ZStack {
            Color.indigo.opacity(0.1)
            Image(systemName: summary.parsedCategories.first?.iconName ?? "map")
                .font(.title3)
                .foregroundStyle(.indigo.opacity(0.5))
        }
    }
}

// MARK: - フィルターチップ（ストア画面用）

private struct CourseStoreFilterChip: View {
    var icon: String? = nil
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(label)
            }
            .font(.subheadline.weight(isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.indigo : Color.secondary.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
