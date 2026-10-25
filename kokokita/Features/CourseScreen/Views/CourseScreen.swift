import SwiftUI

// コース一覧のソート順
enum CourseSortOrder: CaseIterable, Identifiable {
    case updatedAt   // 更新日（デフォルト）
    case spotCount   // スポット数
    case achievedCount // 達成スポット数

    var id: Self { self }

    var label: String {
        switch self {
        case .updatedAt: return L.Course.sortUpdatedAt
        case .spotCount: return L.Course.sortSpotCount
        case .achievedCount: return L.Course.sortAchievedCount
        }
    }

    var iconName: String {
        switch self {
        case .updatedAt: return "clock"
        case .spotCount: return "mappin.and.ellipse"
        case .achievedCount: return "checkmark.seal"
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

// 記録モードのコースタブ（AllCourseListViewのラッパー）
// ストアは唯一の呼び出し元（PilgrimageRootTabView）から常に注入される。
// NotificationCenter登録やUserDefaults読み込みを伴うCourseListStoreを
// 内部で無駄に二重生成しないよう、フォールバックは持たず必須パラメータにしている
struct CourseScreen: View {
    let store: CourseListStore

    var body: some View {
        NavigationStack {
            AllCourseListView(store: store)
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

// MARK: - すべてのコース一覧（コースタブのトップ画面）

struct AllCourseListView: View {
    @Bindable var store: CourseListStore
    @Environment(\.courseFavoriteStore) private var favoriteStore
    @State private var sortOrder: CourseSortOrder = .updatedAt
    @AppStorage(CourseListDisplayMode.storageKey) private var displayModeRaw = CourseListDisplayMode.grid.rawValue
    @State private var selectedFilter: AllCourseFilter = .all
    @State private var showCreateEditor = false
    @State private var isFilterExpanded = true
    @State private var scrollAccumulator: CGFloat = 0

    // private な@Stateプロパティを含むため自動合成されるメンバーワイズイニシャライザが
    // privateになってしまう。storeだけを受け取る公開イニシャライザを明示的に用意する
    init(store: CourseListStore) {
        self.store = store
    }

    private var displayMode: CourseListDisplayMode {
        get { CourseListDisplayMode(rawValue: displayModeRaw) ?? .grid }
        nonmutating set { displayModeRaw = newValue.rawValue }
    }

    // 絞り込みチップに表示するカテゴリ（1件以上コースがあるもののみ）
    // .userCreated は専用の「自作コース」フィルタと重複するためここでは除外する
    private var availableCategories: [CourseCategory] {
        CourseCategory.allCases.filter { category in
            category != .userCreated && store.courses.contains { $0.categories.contains(category) }
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
        sortOrder.applied(to: filteredCourses)
    }

    var body: some View {
        ZStack {
            CourseListBackground()
            courseList
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
        .safeAreaInset(edge: .bottom) {
            filterAreaContent
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Image(systemName: "map")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.indigo)
                    Text(L.Course.listTitle)
                        .font(.headline)
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                CourseDisplayModeToggleButton(displayMode: Binding(
                    get: { displayMode },
                    set: { displayMode = $0 }
                ))
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if store.isSyncing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCreateEditor = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
                .accessibilityLabel(L.Course.createNewButton)
            }
        }
        .navigationDestination(isPresented: $showCreateEditor) {
            CourseEditorView(mode: .create)
        }
        .alert(L.Common.error, isPresented: $store.showError) {
            Button(L.Common.ok) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
        .task {
            await store.syncAndLoad()
        }
        // 表示中の新着コースを視認済みにする（旧NewCoursesSectionが担っていた役割の代替）
        .onAppear {
            store.markAsSeen(ids: displayedCourses.filter { store.isNew($0.id) }.map { $0.id })
        }
        .onChange(of: displayedCourses) { _, newValue in
            store.markAsSeen(ids: newValue.filter { store.isNew($0.id) }.map { $0.id })
        }
    }

    // 下スクロールで絞り込みパネルを引っ込め、上スクロールで再度出す
    // （YouTube/X等を踏襲し、瞬間の動きではなく「同方向にまとまった量スクロールしたか」で判定する。
    // 逆方向に動いたら累積をリセットするので、指を止めた際の微小な揺り戻しでは反応しない）
    private static let scrollDirectionThreshold: CGFloat = 60

    private func handleCourseListScroll(oldValue: CGFloat, newValue: CGFloat) {
        let delta = newValue - oldValue
        guard delta != 0 else { return }

        // 先頭付近まで戻ってきたら常にパネルを見せる
        if newValue <= 0 {
            scrollAccumulator = 0
            guard !isFilterExpanded else { return }
            setFilterExpanded(true)
            return
        }

        // 直前と逆方向に動いた場合は累積をリセットして数え直す
        if (delta > 0 && scrollAccumulator < 0) || (delta < 0 && scrollAccumulator > 0) {
            scrollAccumulator = 0
        }
        scrollAccumulator += delta

        if scrollAccumulator > Self.scrollDirectionThreshold, isFilterExpanded {
            setFilterExpanded(false)
            scrollAccumulator = 0
        } else if scrollAccumulator < -Self.scrollDirectionThreshold, !isFilterExpanded {
            setFilterExpanded(true)
            scrollAccumulator = 0
        }
    }

    // スクロール中のコールバック（onScrollGeometryChange）と同一フレームでレイアウト変更を
    // 伴うアニメーションを開始すると、スクロールの慣性計算と競合してカクつくため、
    // 次のRunLoopに開始タイミングをずらす
    private func setFilterExpanded(_ expanded: Bool) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.22)) { isFilterExpanded = expanded }
        }
    }

    // 絞り込みバー本体。スクロール方向に応じて上下にスライドしながら開閉する
    // （手動での開閉ボタンは一旦廃止し、自動開閉のみとする）
    @ViewBuilder
    private var filterAreaContent: some View {
        if isFilterExpanded {
            AllCourseFilterBar(
                selectedFilter: $selectedFilter,
                availableCategories: availableCategories
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var courseList: some View {
        if store.courses.isEmpty {
            List {
                courseListEmptyState
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
            VStack(spacing: 0) {
                courseListHeader

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
                    .onScrollGeometryChange(for: CGFloat.self) { geometry in
                        geometry.contentOffset.y
                    } action: { oldValue, newValue in
                        handleCourseListScroll(oldValue: oldValue, newValue: newValue)
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
                    .onScrollGeometryChange(for: CGFloat.self) { geometry in
                        geometry.contentOffset.y
                    } action: { oldValue, newValue in
                        handleCourseListScroll(oldValue: oldValue, newValue: newValue)
                    }
                }
            }
        }
    }

    // コース一覧の直上に表示する見出し行（左: 件数 / 右: ソート切り替え）
    // フィルタバーと背景トーンを揃え、一続きのヘッダーに見えるようにする
    private var courseListHeader: some View {
        HStack {
            Text(L.Course.courseCount(displayedCourses.count))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            CourseSortMenu(sortOrder: $sortOrder)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
    }

    // コースが1件もない場合の表示。「同期中」「同期失敗（主にネットワーク不通）」
    // 「同期は成功したが本当に0件」を区別する
    @ViewBuilder
    private var courseListEmptyState: some View {
        if store.isSyncing {
            VStack(spacing: 14) {
                ProgressView()
                Text(L.Course.syncingMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        } else if store.lastSyncFailed {
            ContentUnavailableView {
                Label(L.Course.syncFailedTitle, systemImage: "wifi.slash")
            } description: {
                Text(L.Course.syncFailedDescription)
            } actions: {
                Button(L.Common.retry) {
                    Task { await store.syncAndLoad() }
                }
            }
        } else {
            ContentUnavailableView(
                L.Course.emptyTitle,
                systemImage: "map",
                description: Text(L.Course.emptyDescription)
            )
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
        .background(Color.indigo.opacity(0.1))
        .background(Color(.secondarySystemBackground))
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
            HStack(spacing: 3) {
                Image(systemName: sortOrder.iconName)
                Text(sortOrder.label)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            // ラベルの文字数(更新日順/スポット数順)が変わっても位置がずれないよう幅を固定
            .frame(minWidth: 128, alignment: .trailing)
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
        case .achievedCount:
            return courses.sorted { $0.checkedInCount > $1.checkedInCount }
        }
    }
}
