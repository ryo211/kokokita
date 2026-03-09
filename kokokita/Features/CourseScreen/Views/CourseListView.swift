import SwiftUI

// コース一覧画面
// navigationDestination は呼び出し元の NavigationStack ルートに配置すること
struct CourseListView: View {
    @Bindable var store: CourseListStore
    @State private var selectedCategory: CourseCategory? = nil
    @State private var showCourseStore = false

    private var filteredCourses: [Course] {
        guard let cat = selectedCategory else { return store.courses }
        return store.courses.filter { $0.categories.contains(cat) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // コースがある場合のみカテゴリフィルターバーを表示
            if !store.courses.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CategoryFilterChip(label: L.Home.filterAll, isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        ForEach(CourseCategory.allCases, id: \.rawValue) { category in
                            CategoryFilterChip(
                                icon: category.iconName,
                                label: category.displayName,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = selectedCategory == category ? nil : category
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                Divider()
            }

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
                        let isNew = store.newlyAddedCourseIds.contains(course.id)
                        NavigationLink(value: course.id) {
                            CourseRowView(course: course, isNew: isNew)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task { await store.delete(course.id) }
                            } label: {
                                Label(L.Common.delete, systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle(L.Course.listTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCourseStore = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert(L.Common.error, isPresented: $store.showError) {
            Button(L.Common.ok) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
        .task {
            await store.load()
        }
        .sheet(isPresented: $showCourseStore) {
            CourseStoreSheet()
        }
    }
}

// カテゴリフィルターチップ
private struct CategoryFilterChip: View {
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

// コース行ビュー
private struct CourseRowView: View {
    let course: Course
    var isNew: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // サムネイル
            Group {
                if let urlStr = course.coverImageUrl, let url = URL(string: urlStr) {
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
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // 中: タイトル + タグ（残り幅を確保し折り返し）
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(course.title)
                        .font(.headline)
                    if isNew {
                        Text(L.Course.newBadge)
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.indigo, in: Capsule())
                    }
                }
                if !course.categories.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(course.categories, id: \.rawValue) { category in
                            CourseCategoryTag(category: category)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 右: X/Y + 横プログレスバー
            if course.totalSpotCount > 0 {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(course.checkedInCount)/\(course.totalSpotCount)")
                        .font(.caption2.bold())
                        .foregroundStyle(course.isCompleted ? Color.indigo : Color.secondary)
                        .monospacedDigit()
                    ProgressView(value: Double(course.checkedInCount), total: Double(course.totalSpotCount))
                        .tint(.indigo)
                        .frame(width: 60)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var thumbnailPlaceholder: some View {
        ZStack {
            Color.indigo.opacity(0.1)
            Image(systemName: course.isCompleted ? "checkmark.seal.fill" : (course.categories.first?.iconName ?? "map"))
                .font(.title3)
                .foregroundStyle(.indigo.opacity(0.5))
        }
    }
}

// カテゴリタグ（カプセル形状）
private struct CourseCategoryTag: View {
    let category: CourseCategory

    var body: some View {
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

// タグを折り返すフローレイアウト
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(subviews: subviews, in: proposal.replacingUnspecifiedDimensions().width).bounds
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, in: bounds.width)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: frame.minX + bounds.minX, y: frame.minY + bounds.minY),
                proposal: .unspecified
            )
        }
    }

    private struct LayoutResult {
        var frames: [CGRect] = []
        var bounds = CGSize.zero
    }

    private func layout(subviews: Subviews, in maxWidth: CGFloat) -> LayoutResult {
        var result = LayoutResult()
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            result.frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            result.bounds.width = max(result.bounds.width, x - spacing)
            result.bounds.height = y + lineHeight
        }
        return result
    }
}
