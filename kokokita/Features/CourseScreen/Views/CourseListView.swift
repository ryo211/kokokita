import SwiftUI

// コース一覧画面（カテゴリグリッド）
// navigationDestination は呼び出し元の NavigationStack ルートに配置すること
struct CourseListView: View {
    @Bindable var store: CourseListStore
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var isNewSectionDismissed: Bool = false

    // カテゴリに属するコースを返す
    private func courses(for category: CourseCategory) -> [Course] {
        store.courses.filter { $0.categories.contains(category) }
    }

    // コースが1件以上存在するカテゴリのみ表示
    private var availableCategories: [CourseCategory] {
        CourseCategory.allCases.filter { !courses(for: $0).isEmpty }
    }

    // 検索結果（タイトル部分一致）
    private var searchResults: [Course] {
        guard !searchText.isEmpty else { return [] }
        return store.courses.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    // 新着コース（今回の同期で追加されたもの）
    private var newCourses: [Course] {
        store.courses.filter { store.newlyAddedCourseIds.contains($0.id) }
    }

    var body: some View {
        ZStack {
            CourseListBackground()

            if !searchText.isEmpty {
                // 検索中：フラットなコース一覧
                if searchResults.isEmpty {
                    ContentUnavailableView(
                        L.Course.emptyTitle,
                        systemImage: "magnifyingglass",
                        description: Text("「\(searchText)」に一致するコースはありません")
                    )
                } else {
                    List {
                        ForEach(searchResults) { course in
                            let isNew = store.newlyAddedCourseIds.contains(course.id)
                            NavigationLink(value: course.id) {
                                CourseRowView(course: course, isNew: isNew)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            } else {
                // 通常：カテゴリグリッド
                ScrollView {
                    if store.courses.isEmpty {
                        ContentUnavailableView(
                            L.Course.emptyTitle,
                            systemImage: "plus.circle",
                            description: Text(L.Course.emptyDescription)
                        )
                        .padding(.top, 60)
                    } else {
                        VStack(spacing: 0) {
                            // 新着コースセクション
                            if !newCourses.isEmpty && !isNewSectionDismissed {
                                NewCoursesSection(courses: newCourses) {
                                    withAnimation(.easeOut(duration: 0.25)) {
                                        isNewSectionDismissed = true
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }

                            LazyVGrid(
                                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                                spacing: 12
                            ) {
                                ForEach(availableCategories, id: \.rawValue) { category in
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
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            CourseSearchBar(searchText: $searchText, isFocused: $isSearchFocused)
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
                if store.isSyncing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .alert(L.Common.error, isPresented: $store.showError) {
            Button(L.Common.ok) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
        .task {
            await store.syncAndLoad()
        }
    }
}

// MARK: - 新着コースセクション

private struct NewCoursesSection: View {
    let courses: [Course]
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Label(L.Course.newSectionTitle, systemImage: "sparkles")
                    .font(.subheadline.bold())
                    .foregroundStyle(.indigo)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color(.tertiarySystemFill), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(courses) { course in
                        NavigationLink(value: course.id) {
                            NewCourseCard(course: course)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}

private struct NewCourseCard: View {
    let course: Course

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // カバー画像
            ZStack(alignment: .topTrailing) {
                coverImage
                    .frame(height: 96)
                    .clipped()

                Text(L.Course.newBadge)
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.indigo, in: Capsule())
                    .padding(8)
            }

            // タイトル + スポット数
            VStack(alignment: .leading, spacing: 3) {
                Text(course.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if course.totalSpotCount > 0 {
                    Text("\(course.totalSpotCount)\(L.Course.spotsCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(width: 136)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
    }

    @ViewBuilder
    private var coverImage: some View {
        if let path = course.localCoverImagePath,
           let uiImage = LocalImageStorage.shared.load(from: path) {
            Color.clear.overlay {
                Image(uiImage: uiImage).resizable().scaledToFill()
            }
        } else if let urlStr = course.coverImageUrl, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    Color.clear.overlay { image.resizable().scaledToFill() }
                } else {
                    cardPlaceholder
                }
            }
        } else {
            cardPlaceholder
        }
    }

    private var cardPlaceholder: some View {
        ZStack {
            Color.indigo.opacity(0.12)
            Image(systemName: course.categories.first?.iconName ?? "map")
                .font(.system(size: 30, weight: .thin))
                .foregroundStyle(.indigo.opacity(0.5))
        }
    }
}

// MARK: - 検索バー（画面下部固定）

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

// MARK: - 背景レイヤー

private struct CourseListBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.secondarySystemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            CourseMapBackgroundLayer(
                config: CourseMapBackgroundConfig(
                    style: .structured,
                    seed: 20250128,
                    lineWidth: 1.1,
                    blur: 1.2,
                    opacity: 0.08,
                    exclusionRadiusFactor: 0.18,
                    padding: 24,
                    offset: .zero,
                    organicLineCount: 26,
                    gridSpacing: 84,
                    gridJitter: 10,
                    gridStepMin: 0.75,
                    gridStepMax: 1.15,
                    diagonalChance: 0.4,
                    diagonalBackChance: 0.25,
                    diagonalStride: 2.2,
                    diagonalBackStride: 2.4
                )
            )
        }
        .ignoresSafeArea()
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

private enum CourseMapBackgroundStyle {
    case organic
    case structured
}

private struct CourseMapBackgroundConfig {
    let style: CourseMapBackgroundStyle
    let seed: UInt64
    let lineWidth: CGFloat
    let blur: CGFloat
    let opacity: Double
    let exclusionRadiusFactor: CGFloat
    let padding: CGFloat
    let offset: CGSize
    let organicLineCount: Int
    let gridSpacing: CGFloat
    let gridJitter: CGFloat
    let gridStepMin: CGFloat
    let gridStepMax: CGFloat
    let diagonalChance: Double
    let diagonalBackChance: Double
    let diagonalStride: CGFloat
    let diagonalBackStride: CGFloat
}

private struct CourseMapBackgroundLayer: View {
    let config: CourseMapBackgroundConfig

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.38)
            let radius = min(size.width, size.height) * config.exclusionRadiusFactor
            let strokeColor = colorScheme == .dark ? Color.white : Color.black

            let shape: CourseAnyShape = {
                switch config.style {
                case .organic:
                    return CourseAnyShape(
                        CourseAbstractMapLinesPath(
                            seed: config.seed,
                            lineCount: config.organicLineCount,
                            padding: config.padding,
                            exclusionCenter: center,
                            exclusionRadius: radius
                        )
                    )
                case .structured:
                    return CourseAnyShape(
                        CourseAbstractMapGridPath(
                            seed: config.seed,
                            spacing: config.gridSpacing,
                            jitter: config.gridJitter,
                            stepMin: config.gridStepMin,
                            stepMax: config.gridStepMax,
                            diagonalChance: config.diagonalChance,
                            diagonalBackChance: config.diagonalBackChance,
                            diagonalStride: config.diagonalStride,
                            diagonalBackStride: config.diagonalBackStride,
                            padding: config.padding,
                            exclusionCenter: center,
                            exclusionRadius: radius
                        )
                    )
                }
            }()

            shape.stroke(
                strokeColor,
                style: StrokeStyle(
                    lineWidth: config.lineWidth,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .offset(config.offset)
            .blur(radius: config.blur)
            .opacity(config.opacity)
        }
        .allowsHitTesting(false)
    }
}

private struct CourseAbstractMapLinesPath: Shape {
    let seed: UInt64
    let lineCount: Int
    let padding: CGFloat
    let exclusionCenter: CGPoint
    let exclusionRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var rng = CourseSeededRandom(state: seed)
        var path = Path()
        let bandCount = max(5, Int(sqrt(Double(lineCount))))
        for i in 0..<lineCount {
            var placed = false
            for _ in 0..<3 {
                let isHorizontal = rng.nextDouble() < 0.6
                let isCurved = rng.nextDouble() < 0.75
                let bandIndex = i % bandCount
                let (p0, p1, p2, c0, c1) = makeSmoothCurve(
                    in: rect,
                    horizontal: isHorizontal,
                    bandIndex: bandIndex,
                    bandCount: bandCount,
                    rng: &rng
                )
                let mid = midpoint(p0, p2)
                if isInsideExclusion(mid) {
                    continue
                }
                path.move(to: p0)
                if isCurved {
                    path.addQuadCurve(to: p1, control: c0)
                    path.addQuadCurve(to: p2, control: c1)
                } else {
                    path.addLine(to: p1)
                    path.addLine(to: p2)
                }
                placed = true
                break
            }
            if !placed {
                continue
            }
        }

        return path
    }

    private func makeSmoothCurve(
        in rect: CGRect,
        horizontal: Bool,
        bandIndex: Int,
        bandCount: Int,
        rng: inout CourseSeededRandom
    ) -> (CGPoint, CGPoint, CGPoint, CGPoint, CGPoint) {
        let xMin = rect.minX + padding
        let xMax = rect.maxX - padding
        let yMin = rect.minY + padding
        let yMax = rect.maxY - padding
        let bandSizeY = (yMax - yMin) / CGFloat(bandCount)
        let bandSizeX = (xMax - xMin) / CGFloat(bandCount)

        if horizontal {
            let yBandMin = yMin + CGFloat(bandIndex) * bandSizeY
            let yBandMax = min(yBandMin + bandSizeY, yMax)
            let y = rng.nextCGFloat(in: yBandMin...yBandMax)
            let x0 = rng.nextCGFloat(in: xMin...xMax * 0.30)
            let x2 = rng.nextCGFloat(in: xMax * 0.70...xMax)
            let bend = rng.nextCGFloat(in: -28...28)
            let p0 = CGPoint(x: x0, y: y)
            let p2 = CGPoint(x: x2, y: y + bend)
            let p1 = CGPoint(
                x: lerp(x0, x2, t: 0.5) + rng.nextCGFloat(in: -10...10),
                y: y + rng.nextCGFloat(in: -8...8)
            )
            let c0 = CGPoint(
                x: lerp(x0, x2, t: 0.25),
                y: y + rng.nextCGFloat(in: -24...24)
            )
            let c1 = CGPoint(
                x: lerp(x0, x2, t: 0.75),
                y: y + bend + rng.nextCGFloat(in: -24...24)
            )
            return (p0, p1, p2, c0, c1)
        } else {
            let xBandMin = xMin + CGFloat(bandIndex) * bandSizeX
            let xBandMax = min(xBandMin + bandSizeX, xMax)
            let x = rng.nextCGFloat(in: xBandMin...xBandMax)
            let y0 = rng.nextCGFloat(in: yMin...yMax * 0.30)
            let y2 = rng.nextCGFloat(in: yMax * 0.70...yMax)
            let bend = rng.nextCGFloat(in: -28...28)
            let p0 = CGPoint(x: x, y: y0)
            let p2 = CGPoint(x: x + bend, y: y2)
            let p1 = CGPoint(
                x: x + rng.nextCGFloat(in: -8...8),
                y: lerp(y0, y2, t: 0.5) + rng.nextCGFloat(in: -10...10)
            )
            let c0 = CGPoint(
                x: x + rng.nextCGFloat(in: -24...24),
                y: lerp(y0, y2, t: 0.25)
            )
            let c1 = CGPoint(
                x: x + bend + rng.nextCGFloat(in: -24...24),
                y: lerp(y0, y2, t: 0.75)
            )
            return (p0, p1, p2, c0, c1)
        }
    }

    private func isInsideExclusion(_ point: CGPoint) -> Bool {
        let dx = point.x - exclusionCenter.x
        let dy = point.y - exclusionCenter.y
        return (dx * dx + dy * dy) < (exclusionRadius * exclusionRadius)
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    private func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) * 0.5, y: (a.y + b.y) * 0.5)
    }
}

private struct CourseAbstractMapGridPath: Shape {
    let seed: UInt64
    let spacing: CGFloat
    let jitter: CGFloat
    let stepMin: CGFloat
    let stepMax: CGFloat
    let diagonalChance: Double
    let diagonalBackChance: Double
    let diagonalStride: CGFloat
    let diagonalBackStride: CGFloat
    let padding: CGFloat
    let exclusionCenter: CGPoint
    let exclusionRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var rng = CourseSeededRandom(state: seed)
        var path = Path()
        let xMin = rect.minX + padding
        let xMax = rect.maxX - padding
        let yMin = rect.minY + padding
        let yMax = rect.maxY - padding

        var y = yMin
        while y <= yMax {
            let yJitter = rng.nextCGFloat(in: -jitter...jitter)
            let start = CGPoint(x: xMin, y: y + yJitter)
            let end = CGPoint(x: xMax, y: y + yJitter + rng.nextCGFloat(in: -jitter...jitter))
            if !isInsideExclusion(midpoint(start, end)) {
                path.move(to: start)
                path.addLine(to: end)
            }
            y += spacing * rng.nextCGFloat(in: stepMin...stepMax)
        }

        var x = xMin
        while x <= xMax {
            let xJitter = rng.nextCGFloat(in: -jitter...jitter)
            let start = CGPoint(x: x + xJitter, y: yMin)
            let end = CGPoint(x: x + xJitter + rng.nextCGFloat(in: -jitter...jitter), y: yMax)
            if !isInsideExclusion(midpoint(start, end)) {
                path.move(to: start)
                path.addLine(to: end)
            }
            x += spacing * rng.nextCGFloat(in: stepMin...stepMax)
        }

        var d = xMin
        while d <= xMax {
            if rng.nextDouble() < diagonalChance {
                let start = CGPoint(x: d, y: yMin)
                let end = CGPoint(x: d + (yMax - yMin), y: yMax)
                if !isInsideExclusion(midpoint(start, end)) {
                    path.move(to: start)
                    path.addLine(to: end)
                }
            }
            d += spacing * diagonalStride
        }

        var d2 = xMax
        while d2 >= xMin {
            if rng.nextDouble() < diagonalBackChance {
                let start = CGPoint(x: d2, y: yMin)
                let end = CGPoint(x: d2 - (yMax - yMin), y: yMax)
                if !isInsideExclusion(midpoint(start, end)) {
                    path.move(to: start)
                    path.addLine(to: end)
                }
            }
            d2 -= spacing * diagonalBackStride
        }

        return path
    }

    private func isInsideExclusion(_ point: CGPoint) -> Bool {
        let dx = point.x - exclusionCenter.x
        let dy = point.y - exclusionCenter.y
        return (dx * dx + dy * dy) < (exclusionRadius * exclusionRadius)
    }

    private func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) * 0.5, y: (a.y + b.y) * 0.5)
    }
}

private struct CourseAnyShape: Shape, @unchecked Sendable {
    private let _path: @Sendable (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        _path = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}

private struct CourseSeededRandom {
    var state: UInt64

    mutating func next() -> UInt64 {
        state = 2862933555777941757 &* state &+ 3037000493
        return state
    }

    mutating func nextDouble() -> Double {
        Double(next() % 1_000_000) / 1_000_000
    }

    mutating func nextCGFloat(in range: ClosedRange<CGFloat>) -> CGFloat {
        let t = CGFloat(nextDouble())
        return range.lowerBound + (range.upperBound - range.lowerBound) * t
    }
}
