import SwiftUI

// お気に入り一覧へのナビゲーション識別子
struct FavoritesNavTarget: Hashable {}

// すべてのコース一覧へのナビゲーション識別子
struct AllCoursesNavTarget: Hashable {}

// コース一覧のソート順
enum CourseSortOrder: CaseIterable, Identifiable {
    case updatedAt   // 更新日（デフォルト）
    case spotCount   // スポット数

    var id: Self { self }

    var label: String {
        switch self {
        case .updatedAt: return L.Course.sortUpdatedAt
        case .spotCount: return L.Course.sortSpotCount
        }
    }

    var iconName: String {
        switch self {
        case .updatedAt: return "clock"
        case .spotCount: return "mappin.and.ellipse"
        }
    }
}

// 記録モードのコースタブ（CourseListViewのラッパー）
// ストアを所有し、navigationDestination をルートに配置
struct CourseScreen: View {
    /// 外部から注入されるストア（nilの場合は内部で生成）
    var externalStore: CourseListStore? = nil
    @State private var ownStore = CourseListStore()

    private var store: CourseListStore { externalStore ?? ownStore }

    var body: some View {
        NavigationStack {
            CourseListView(store: store)
                // カテゴリ選択 → フィルター済みコース一覧（ネイティブ push でスワイプバック対応）
                .navigationDestination(for: CourseCategory.self) { category in
                    CategoryCourseListView(category: category, store: store)
                }
                // すべてのコース一覧
                .navigationDestination(for: AllCoursesNavTarget.self) { _ in
                    AllCourseListView(store: store)
                }
                // お気に入り一覧
                .navigationDestination(for: FavoritesNavTarget.self) { _ in
                    FavoriteCourseListView(store: store)
                }
                // コース詳細
                .navigationDestination(for: UUID.self) { courseId in
                    if let course = store.courses.first(where: { $0.id == courseId }) {
                        CourseDetailView(course: course, courseListStore: store, showSummaryOnAppear: true)
                    }
                }
        }
        .onReceive(NotificationCenter.default.publisher(for: .courseChanged)) { _ in
            Task { await store.load() }
        }
    }
}

// MARK: - すべてのコース一覧

private struct AllCourseListView: View {
    @Bindable var store: CourseListStore
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var sortOrder: CourseSortOrder = .updatedAt

    private var displayedCourses: [Course] {
        let filtered = searchText.isEmpty
            ? store.courses
            : store.courses.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        return sortOrder.applied(to: filtered)
    }

    var body: some View {
        courseList
            .listStyle(.plain)
            .safeAreaInset(edge: .bottom) {
                CourseSearchBar(searchText: $searchText, isFocused: $isSearchFocused)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.grid.2x2")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.indigo)
                        Text(L.Course.categoryAll)
                            .font(.headline)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    CourseSortMenu(sortOrder: $sortOrder)
                }
            }
    }

    @ViewBuilder
    private var courseList: some View {
        if !searchText.isEmpty && displayedCourses.isEmpty {
            List {
                ContentUnavailableView(
                    L.Course.emptyTitle,
                    systemImage: "magnifyingglass",
                    description: Text("「\(searchText)」に一致するコースはありません")
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        } else if store.courses.isEmpty {
            List {
                ContentUnavailableView(
                    L.Course.emptyTitle,
                    systemImage: "plus.circle",
                    description: Text(L.Course.emptyDescription)
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        } else {
            List {
                ForEach(displayedCourses) { course in
                    let isNew = store.isNew(course.id)
                    NavigationLink(value: course.id) {
                        CourseRowView(course: course, isNew: isNew)
                    }
                }
            }
        }
    }
}

// MARK: - カテゴリ別コース一覧

private struct CategoryCourseListView: View {
    let category: CourseCategory
    @Bindable var store: CourseListStore
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var sortOrder: CourseSortOrder = .updatedAt

    private var baseCourses: [Course] {
        store.courses.filter { $0.categories.contains(category) }
    }

    private var displayedCourses: [Course] {
        let filtered = searchText.isEmpty
            ? baseCourses
            : baseCourses.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        return sortOrder.applied(to: filtered)
    }

    var body: some View {
        courseList
            .listStyle(.plain)
            .safeAreaInset(edge: .bottom) {
                CourseSearchBar(searchText: $searchText, isFocused: $isSearchFocused)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: category.iconName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.indigo)
                        Text(category.displayName)
                            .font(.headline)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    CourseSortMenu(sortOrder: $sortOrder)
                }
            }
    }

    @ViewBuilder
    private var courseList: some View {
        if !searchText.isEmpty && displayedCourses.isEmpty {
            List {
                ContentUnavailableView(
                    L.Course.emptyTitle,
                    systemImage: "magnifyingglass",
                    description: Text("「\(searchText)」に一致するコースはありません")
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        } else if baseCourses.isEmpty {
            List {
                ContentUnavailableView(
                    L.Course.emptyTitle,
                    systemImage: "plus.circle",
                    description: Text(L.Course.emptyDescription)
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        } else {
            List {
                ForEach(displayedCourses) { course in
                    let isNew = store.isNew(course.id)
                    NavigationLink(value: course.id) {
                        CourseRowView(course: course, isNew: isNew)
                    }
                }
            }
        }
    }
}

// MARK: - お気に入りコース一覧

private struct FavoriteCourseListView: View {
    @Bindable var store: CourseListStore
    @Environment(\.courseFavoriteStore) private var favoriteStore
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var sortOrder: CourseSortOrder = .updatedAt

    private var baseCourses: [Course] {
        favoriteStore.orderedFavoriteIds
            .reversed()
            .compactMap { id in store.courses.first(where: { $0.id == id }) }
    }

    private var displayedCourses: [Course] {
        let filtered = searchText.isEmpty
            ? baseCourses
            : baseCourses.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        return sortOrder.applied(to: filtered)
    }

    var body: some View {
        courseList
            .listStyle(.plain)
            .safeAreaInset(edge: .bottom) {
                CourseSearchBar(searchText: $searchText, isFocused: $isSearchFocused)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.indigo)
                        Text(L.Course.favoriteSectionTitle)
                            .font(.headline)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    CourseSortMenu(sortOrder: $sortOrder)
                }
            }
    }

    @ViewBuilder
    private var courseList: some View {
        if !searchText.isEmpty && displayedCourses.isEmpty {
            List {
                ContentUnavailableView(
                    L.Course.emptyTitle,
                    systemImage: "magnifyingglass",
                    description: Text("「\(searchText)」に一致するコースはありません")
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        } else if baseCourses.isEmpty {
            List {
                ContentUnavailableView(
                    L.Course.favoriteSectionTitle,
                    systemImage: "heart",
                    description: Text(L.Course.favoriteEmptyDescription)
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        } else {
            List {
                ForEach(displayedCourses) { course in
                    let isNew = store.isNew(course.id)
                    NavigationLink(value: course.id) {
                        CourseRowView(course: course, isNew: isNew)
                    }
                }
            }
        }
    }
}

// MARK: - ソートメニュー

private struct CourseSortMenu: View {
    @Binding var sortOrder: CourseSortOrder

    var body: some View {
        Menu {
            Picker(selection: $sortOrder) {
                ForEach(CourseSortOrder.allCases) { order in
                    Label(order.label, systemImage: order.iconName).tag(order)
                }
            } label: {}
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 15, weight: .medium))
        }
    }
}

// MARK: - CourseSortOrder ソートロジック

private extension CourseSortOrder {
    func applied(to courses: [Course]) -> [Course] {
        switch self {
        case .updatedAt:
            return courses.sorted { $0.updatedAt > $1.updatedAt }
        case .spotCount:
            return courses.sorted { $0.totalSpotCount > $1.totalSpotCount }
        }
    }
}
