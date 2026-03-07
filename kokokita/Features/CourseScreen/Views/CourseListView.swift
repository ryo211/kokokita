import SwiftUI

// コース一覧画面
// navigationDestination は呼び出し元の NavigationStack ルートに配置すること
struct CourseListView: View {
    @Bindable var store: CourseListStore
    @State private var selectedCategory: CourseCategory? = nil

    private var filteredCourses: [Course] {
        guard let cat = selectedCategory else { return store.courses }
        return store.courses.filter { $0.categories.contains(cat) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // カテゴリフィルターバー
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

            List {
                if filteredCourses.isEmpty {
                    ContentUnavailableView(
                        L.Course.emptyTitle,
                        systemImage: "list.bullet",
                        description: Text(L.Course.emptyDescription)
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredCourses) { course in
                        NavigationLink(value: course.id) {
                            CourseRowView(course: course)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert(L.Common.error, isPresented: $store.showError) {
            Button(L.Common.ok) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
        .task {
            await store.load()
        }
        .sheet(item: $store.retroactiveResult) { result in
            RetroactiveCheckInResultSheet(result: result)
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

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 左: インジケーター + タイトル + タグ（残り幅を確保し折り返し）
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(course.isCompleted ? Color.indigo : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                    Text(course.title)
                        .font(.headline)
                }
                if !course.categories.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(course.categories, id: \.rawValue) { category in
                            CourseCategoryTag(category: category)
                        }
                    }
                    .padding(.leading, 16)
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
