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

// コース一覧の表示形式（リスト / グリッド）
// 全カテゴリ・全コース一覧画面で共通の @AppStorage キーを使い、選択状態を横断的に保持する
enum CourseListDisplayMode: String {
    case list
    case grid

    static let storageKey = "courseList.displayModeRaw"
}

// 記録モードのコースタブ（CourseListViewのラッパー）
// ストアは唯一の呼び出し元（PilgrimageRootTabView）から常に注入される。
// NotificationCenter登録やUserDefaults読み込みを伴うCourseListStoreを
// 内部で無駄に二重生成しないよう、フォールバックは持たず必須パラメータにしている
struct CourseScreen: View {
    let store: CourseListStore

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

// MARK: - すべてのコース一覧の絞り込み

private enum AllCourseFilter: Hashable {
    case all
    case new
    case favorite
    case userCreated
    case category(CourseCategory)
}

// MARK: - すべてのコース一覧

private struct AllCourseListView: View {
    @Bindable var store: CourseListStore
    @Environment(\.courseFavoriteStore) private var favoriteStore
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var sortOrder: CourseSortOrder = .updatedAt
    @AppStorage(CourseListDisplayMode.storageKey) private var displayModeRaw = CourseListDisplayMode.list.rawValue
    @State private var selectedFilter: AllCourseFilter = .all

    private var displayMode: CourseListDisplayMode {
        get { CourseListDisplayMode(rawValue: displayModeRaw) ?? .list }
        nonmutating set { displayModeRaw = newValue.rawValue }
    }

    // 絞り込みチップに表示するカテゴリ（1件以上コースがあるもののみ）
    private var availableCategories: [CourseCategory] {
        CourseCategory.allCases.filter { category in
            store.courses.contains { $0.categories.contains(category) }
        }
    }

    private var filteredCourses: [Course] {
        switch selectedFilter {
        case .all:
            return store.courses
        case .new:
            return store.courses.filter { store.isNew($0.id) }
        case .favorite:
            return store.courses.filter { favoriteStore.isFavorite($0.id) }
        case .userCreated:
            return store.courses.filter { $0.isUserCreated }
        case .category(let category):
            return store.courses.filter { $0.categories.contains(category) }
        }
    }

    private var displayedCourses: [Course] {
        let filtered = searchText.isEmpty
            ? filteredCourses
            : filteredCourses.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        return sortOrder.applied(to: filtered)
    }

    var body: some View {
        ZStack {
            CourseListBackground()
            courseList
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
        .safeAreaInset(edge: .top) {
            AllCourseFilterBar(selectedFilter: $selectedFilter, availableCategories: availableCategories)
        }
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
                CourseDisplayModeToggleButton(displayMode: Binding(
                    get: { displayMode },
                    set: { displayMode = $0 }
                ))
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
        } else if filteredCourses.isEmpty {
            List {
                ContentUnavailableView(
                    L.Course.emptyTitle,
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text(L.Course.filterEmptyDescription)
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        } else {
            switch displayMode {
            case .list:
                List {
                    ForEach(displayedCourses) { course in
                        let isNew = store.isNew(course.id)
                        NavigationLink(value: course.id) {
                            CourseRowView(course: course, isNew: isNew)
                        }
                    }
                }
            case .grid:
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                        spacing: 10
                    ) {
                        ForEach(Array(displayedCourses.enumerated()), id: \.element.id) { index, course in
                            let isNew = store.isNew(course.id)
                            NavigationLink(value: course.id) {
                                CourseGridEntranceCell(index: index) {
                                    CourseHeroGridCard(course: course, isNew: isNew, showCategory: true)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }
}

// MARK: - すべてのコース一覧の絞り込みチップバー

private struct AllCourseFilterBar: View {
    @Binding var selectedFilter: AllCourseFilter
    let availableCategories: [CourseCategory]

    var body: some View {
        VStack(spacing: 0) {
            FlowLayout(spacing: 6) {
                chip(title: L.Course.categoryAll, icon: "square.grid.2x2", filter: .all)
                chip(title: L.Course.filterNew, icon: "star.fill", filter: .new)
                chip(title: L.Course.favoriteSectionTitle, icon: "heart.fill", filter: .favorite)
                chip(title: L.Course.filterUserCreated, icon: "person.crop.square", filter: .userCreated)
                ForEach(availableCategories, id: \.rawValue) { category in
                    chip(title: category.displayName, icon: category.iconName, filter: .category(category))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()
        }
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private func chip(title: String, icon: String, filter: AllCourseFilter) -> some View {
        let isSelected = selectedFilter == filter
        Button {
            selectedFilter = filter
        } label: {
            HStack(spacing: 3) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Color.indigo : Color(.tertiarySystemFill), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - カテゴリ別コース一覧

private struct CategoryCourseListView: View {
    let category: CourseCategory
    @Bindable var store: CourseListStore
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var sortOrder: CourseSortOrder = .updatedAt
    @AppStorage(CourseListDisplayMode.storageKey) private var displayModeRaw = CourseListDisplayMode.list.rawValue

    private var displayMode: CourseListDisplayMode {
        get { CourseListDisplayMode(rawValue: displayModeRaw) ?? .list }
        nonmutating set { displayModeRaw = newValue.rawValue }
    }

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
        ZStack {
            CourseListBackground()
            courseList
        }
        .scrollContentBackground(.hidden)
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
                CourseDisplayModeToggleButton(displayMode: Binding(
                    get: { displayMode },
                    set: { displayMode = $0 }
                ))
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
            switch displayMode {
            case .list:
                List {
                    ForEach(displayedCourses) { course in
                        let isNew = store.isNew(course.id)
                        NavigationLink(value: course.id) {
                            CourseRowView(course: course, isNew: isNew)
                        }
                    }
                }
            case .grid:
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                        spacing: 10
                    ) {
                        ForEach(Array(displayedCourses.enumerated()), id: \.element.id) { index, course in
                            let isNew = store.isNew(course.id)
                            NavigationLink(value: course.id) {
                                CourseGridEntranceCell(index: index) {
                                    CourseHeroGridCard(course: course, isNew: isNew)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }
}

// MARK: - 表示形式切り替えボタン

private struct CourseDisplayModeToggleButton: View {
    @Binding var displayMode: CourseListDisplayMode

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                displayMode = displayMode == .list ? .grid : .list
            }
        } label: {
            Image(systemName: displayMode == .list ? "square.grid.3x2" : "list.bullet")
                .font(.system(size: 15, weight: .medium))
        }
        .accessibilityLabel(displayMode == .list ? L.Course.displayModeSwitchToGrid : L.Course.displayModeSwitchToList)
    }
}

// MARK: - グリッドカードのエントランスアニメーション

// 開いた瞬間に上から段階的にふわっと現れる演出。行番号ベースで遅延をつける
private struct CourseGridEntranceCell<Content: View>: View {
    let index: Int
    @ViewBuilder var content: () -> Content
    @State private var appeared = false

    private static var columnCount: Int { 3 }

    var body: some View {
        content()
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
            .onAppear {
                guard !appeared else { return }
                let row = index / Self.columnCount
                let delay = min(Double(row) * 0.05, 0.4)
                withAnimation(.easeOut(duration: 0.35).delay(delay)) {
                    appeared = true
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
