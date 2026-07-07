import SwiftUI

// お気に入り一覧へのナビゲーション識別子
struct FavoritesNavTarget: Hashable {}

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

// MARK: - カテゴリ別コース一覧

private struct CategoryCourseListView: View {
    let category: CourseCategory
    @Bindable var store: CourseListStore

    private var filteredCourses: [Course] {
        store.courses.filter { $0.categories.contains(category) }
    }

    var body: some View {
        List {
            if filteredCourses.isEmpty {
                ContentUnavailableView(
                    L.Course.emptyTitle,
                    systemImage: "plus.circle",
                    description: Text(L.Course.emptyDescription)
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(filteredCourses) { course in
                    let isNew = store.isNew(course.id)
                    NavigationLink(value: course.id) {
                        CourseRowView(course: course, isNew: isNew)
                    }
                }
            }
        }
        .listStyle(.plain)
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
        }
    }
}

// MARK: - お気に入りコース一覧

private struct FavoriteCourseListView: View {
    @Bindable var store: CourseListStore
    @Environment(\.courseFavoriteStore) private var favoriteStore

    private var favoriteCourses: [Course] {
        favoriteStore.orderedFavoriteIds
            .reversed()
            .compactMap { id in store.courses.first(where: { $0.id == id }) }
    }

    var body: some View {
        List {
            if favoriteCourses.isEmpty {
                ContentUnavailableView(
                    L.Course.favoriteSectionTitle,
                    systemImage: "heart",
                    description: Text(L.Course.favoriteEmptyDescription)
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(favoriteCourses) { course in
                    let isNew = store.isNew(course.id)
                    NavigationLink(value: course.id) {
                        CourseRowView(course: course, isNew: isNew)
                    }
                }
            }
        }
        .listStyle(.plain)
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
        }
    }
}
