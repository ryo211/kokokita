import SwiftUI

// コースのカバー画像表示ロジック（ローカル → リモート(キャッシュ付き) → プレースホルダー）を共通化
// CourseRowView / CourseHeroGridCard / StampCard で共有
@ViewBuilder
func courseCoverImage<Placeholder: View>(
    localPath: String?,
    remoteURLString: String?,
    @ViewBuilder placeholder: () -> Placeholder
) -> some View {
    if let path = localPath,
       let uiImage = LocalImageStorage.shared.load(from: path) {
        Color.clear.overlay {
            Image(uiImage: uiImage).resizable().scaledToFill()
        }
        .clipped()
    } else if let urlStr = remoteURLString, let url = URL(string: urlStr) {
        ZStack {
            placeholder()
            CachedCourseImage(url: url)
        }
    } else {
        placeholder()
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

            TextField(L.Course.searchPlaceholder, text: $searchText)
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

struct CourseListBackground: View {
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

// MARK: - コース行ビュー

struct CourseRowView: View {
    let course: Course
    var isNew: Bool = false
    @Environment(\.courseFavoriteStore) private var favoriteStore

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // サムネイル
            // scaledToFill はレイアウトサイズを超えて報告するため
            // Color.clear.overlay { image }.clipped() パターンで確実に封じる
            thumbnailImage
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

            // 右: X/Y + 横プログレスバー + お気に入りボタン
            VStack(alignment: .trailing, spacing: 4) {
                if course.totalSpotCount > 0 {
                    Text("\(course.checkedInCount)/\(course.totalSpotCount)")
                        .font(.caption2.bold())
                        .foregroundStyle(course.isCompleted ? Color.indigo : Color.secondary)
                        .monospacedDigit()
                    ProgressView(value: Double(course.checkedInCount), total: Double(course.totalSpotCount))
                        .tint(.indigo)
                        .frame(width: 60)
                }

                let isFavorite = favoriteStore.isFavorite(course.id)
                Button {
                    favoriteStore.toggle(course.id)
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 18))
                        .foregroundStyle(isFavorite ? Color.indigo : Color.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isFavorite ? L.Course.favoriteToggleRemove : L.Course.favoriteToggleAdd)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var thumbnailImage: some View {
        courseCoverImage(
            localPath: course.localCoverImagePath,
            remoteURLString: course.coverImageUrl,
            placeholder: { thumbnailPlaceholder }
        )
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

// MARK: - コースヒーローグリッドカード（3列グリッド表示用）

struct CourseHeroGridCard: View {
    let course: Course
    var isNew: Bool = false
    // 「すべて」一覧など複数カテゴリが混在する文脈でのみ、代表カテゴリを1つ表示する
    var showCategory: Bool = false
    @Environment(\.courseFavoriteStore) private var favoriteStore

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            courseCoverImage(
                localPath: course.localCoverImagePath,
                remoteURLString: course.coverImageUrl,
                placeholder: { coverPlaceholder }
            )

            LinearGradient(
                colors: [Color.black.opacity(0.10), Color.black.opacity(0.68)],
                startPoint: .top,
                endPoint: .bottom
            )

            if isNew {
                Text(L.Course.newBadge)
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.indigo, in: Capsule())
                    .padding(6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            favoriteButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            VStack(alignment: .leading, spacing: 3) {
                if showCategory, let category = course.categories.first {
                    HStack(spacing: 2) {
                        Image(systemName: category.iconName)
                        Text(category.displayName)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.22), in: Capsule())
                    .fixedSize()
                }

                Text(course.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.3), radius: 2)

                if course.totalSpotCount > 0 {
                    HStack(spacing: 4) {
                        ProgressView(value: Double(course.checkedInCount), total: Double(course.totalSpotCount))
                            .tint(course.isCompleted ? Color.green : Color.white)
                        Text("\(course.checkedInCount)/\(course.totalSpotCount)")
                            .font(.caption2.bold())
                            .foregroundStyle(.white.opacity(0.85))
                            .monospacedDigit()
                    }
                }
            }
            .padding(8)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fill)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var coverPlaceholder: some View {
        ZStack {
            Color.indigo.opacity(0.12)
            Image(systemName: course.categories.first?.iconName ?? "map")
                .font(.system(size: 26, weight: .thin))
                .foregroundStyle(.indigo.opacity(0.5))
        }
    }

    private var favoriteButton: some View {
        let isFavorite = favoriteStore.isFavorite(course.id)
        return Button {
            favoriteStore.toggle(course.id)
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isFavorite ? Color.red : Color.white)
                .frame(width: 26, height: 26)
                .background(.black.opacity(0.32), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(6)
        .accessibilityLabel(isFavorite ? L.Course.favoriteToggleRemove : L.Course.favoriteToggleAdd)
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
