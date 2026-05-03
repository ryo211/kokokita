import SwiftUI

// コース一覧画面（カテゴリグリッド）
// navigationDestination は呼び出し元の NavigationStack ルートに配置すること
struct CourseListView: View {
    @Bindable var store: CourseListStore
    @State private var showCourseStore = false
    @State private var storeSheetStore = CourseStoreSheetStore()

    // カテゴリに属するコースを返す
    private func courses(for category: CourseCategory) -> [Course] {
        store.courses.filter { $0.categories.contains(category) }
    }

    // コースが1件以上存在するカテゴリのみ表示
    private var availableCategories: [CourseCategory] {
        CourseCategory.allCases.filter { !courses(for: $0).isEmpty }
    }

    var body: some View {
        ScrollView {
            if store.courses.isEmpty {
                ContentUnavailableView(
                    L.Course.emptyTitle,
                    systemImage: "plus.circle",
                    description: Text(L.Course.emptyDescription)
                )
                .padding(.top, 60)
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(availableCategories, id: \.rawValue) { category in
                        // NavigationLink で push することでネイティブスワイプバックが使える
                        NavigationLink(value: category) {
                            CategoryGridCard(
                                category: category,
                                courses: courses(for: category)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
            }
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
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCourseStore = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "plus")
                        if storeSheetStore.hasNewArrivals {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .offset(x: 6, y: -6)
                        }
                    }
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
        .task {
            await storeSheetStore.loadIndex()
        }
        .sheet(isPresented: $showCourseStore) {
            CourseStoreSheet(store: storeSheetStore)
        }
    }
}

// MARK: - カテゴリグリッドカード

private struct CategoryGridCard: View {
    let category: CourseCategory
    let courses: [Course]

    // カバー画像があるコースを代表として優先選択
    private var representativeCourse: Course? {
        courses.first(where: { $0.coverImageUrl != nil || $0.localCoverImagePath != nil })
        ?? courses.first
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // 背景画像レイヤー
            backgroundLayer

            // 共通グラデーションオーバーレイ（画像あり・なし共通で見た目を揃える）
            LinearGradient(
                colors: [Color.black.opacity(0.08), Color.black.opacity(0.60)],
                startPoint: .top,
                endPoint: .bottom
            )

            // テキストコンテンツ（下部）
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: category.iconName)
                        .font(.caption.weight(.semibold))
                    Text(category.displayName)
                        .font(.subheadline.bold())
                }
                .foregroundStyle(.white)

                // コース名（最大2件、3件以上は省略行を追加）
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(courses.prefix(2)) { course in
                        Text(course.title)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.80))
                            .lineLimit(1)
                    }
                    if courses.count > 2 {
                        Text("ほか\(courses.count - 2)コース")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }
            .padding(12)
        }
        .frame(height: 148)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // 画像レイヤー（ローカル → リモート → プレースホルダーの順）
    // scaledToFill はレイアウトサイズを超えて報告してしまうため
    // Color.clear.overlay { image }.clipped() パターンで確実に封じる
    @ViewBuilder
    private var backgroundLayer: some View {
        if let path = representativeCourse?.localCoverImagePath,
           let uiImage = LocalImageStorage.shared.load(from: path) {
            Color.clear.overlay {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
        } else if let urlStr = representativeCourse?.coverImageUrl,
                  let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    Color.clear.overlay {
                        image.resizable().scaledToFill()
                    }
                    .clipped()
                } else {
                    placeholderBackground
                }
            }
        } else {
            placeholderBackground
        }
    }

    // 画像なしプレースホルダー
    // 中明度グレー + カテゴリアイコン（薄く）で、グラデーション後に画像カードと同系の見た目になる
    private var placeholderBackground: some View {
        ZStack {
            Color(white: 0.68)
            Image(systemName: category.iconName)
                .font(.system(size: 52, weight: .thin))
                .foregroundStyle(Color.white.opacity(0.45))
        }
    }
}

// MARK: - コース行ビュー

struct CourseRowView: View {
    let course: Course
    var isNew: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // サムネイル
            // ローカル保存画像 → リモートURL → プレースホルダーの順で優先
            Group {
                if let path = course.localCoverImagePath,
                   let uiImage = LocalImageStorage.shared.load(from: path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else if let urlStr = course.coverImageUrl, let url = URL(string: urlStr) {
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

// MARK: - カテゴリタグ（カプセル形状）

struct CourseCategoryTag: View {
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

// MARK: - タグを折り返すフローレイアウト

struct FlowLayout: Layout {
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
