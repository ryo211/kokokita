import SwiftUI

struct HomeScreen: View {
    @Environment(AppUIState.self) private var ui
    @State private var showSettings = false
    @State private var store = VisitListStore(repo: AppContainer.shared.repo)
    @State private var isPulsing = true
    @State private var recentVisits: [VisitAggregate]? = nil  // nilで初期化
    @State private var hasStartedAnimation = false

    let onKokokitaTap: () -> Void
    let onViewAllTap: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景グラデーション
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.secondarySystemBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                // 抽象ライン（地図っぽい雰囲気）
                MapBackgroundLayer(
                    config: MapBackgroundConfig(
                        style: .structured, // .structuredで規則的な地図感、.organicで有機的な路線
                        seed: 20250128, // 同じ値なら再現性あり（端末サイズが同じ場合）
                        lineWidth: 1.1, // 線の太さ
                        blur: 1.2, // ぼかし量（小さいほどシャープ）
                        opacity: 0.08, // 視認性の強さ
                        exclusionRadiusFactor: 0.18, // 中央主役を避ける範囲（画面最小辺に対する割合）
                        padding: 24, // 端からの余白
                        offset: .zero, // 背景全体の移動（将来パララックス用）
                        organicLineCount: 26, // organic時の本数
                        gridSpacing: 84, // structured時の格子間隔（大きいほど本数が減る）
                        gridJitter: 10, // structured時の歪み量（小さいほど整然）
                        gridStepMin: 0.75, // 格子間隔のゆらぎ下限
                        gridStepMax: 1.15, // 格子間隔のゆらぎ上限
                        diagonalChance: 0.4, // 斜めラインの出現確率（幹線感）
                        diagonalBackChance: 0.25, // 逆方向の斜めライン確率
                        diagonalStride: 2.2, // 斜めライン間隔の倍率（大きいほど減る）
                        diagonalBackStride: 2.4 // 逆方向斜めライン間隔の倍率
                    )
                )
                .ignoresSafeArea()

                VStack(spacing: 40) {
                    Spacer()

                    // メイン: 大きなKokokitaボタン
                    kokokitaButton

                    Spacer()

                    // 最近の記録カルーセル（高さ固定）
                    Group {
                        if let visits = recentVisits {
                            if !visits.isEmpty {
                                recentRecordsSection
                            } else {
                                emptyRecordsPlaceholder
                            }
                        } else {
                            // データ取得中は何も表示しない
                            Color.clear
                        }
                    }
                    .frame(height: 140)
                }
                .padding(.bottom, 24)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showSettings) {
                SettingsSheet()
            }
        }
        .task {
            // アニメーション開始（初回のみ）-
             if !hasStartedAnimation {
                 hasStartedAnimation = true
                 withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                     isPulsing.toggle()
                 }
             }

            store.reload()
            loadRecentVisits()
        }
        .onReceive(NotificationCenter.default.publisher(for: .visitsChanged)) { _ in
            Task {
                store.reload()
                loadRecentVisits()
            }
        }
    }

    // MARK: - Kokokita Button

    private var kokokitaButton: some View {
        Button {
            onKokokitaTap()
        } label: {
            VStack(spacing: 48) {
                // Liquid Glass円形ボタン
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.accentColor.opacity(0.2),
                                            Color.accentColor.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.accentColor.opacity(0.4),
                                            Color.accentColor.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        }
                        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
                        .shadow(color: Color.accentColor.opacity(0.3), radius: 30, x: 0, y: 15)  // 一時的に固定値

                    Image("kokokita_irodori_blue")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                }
                .frame(width: 140, height: 140)
                 .scaleEffect(isPulsing ? 1.08 : 1.0, anchor: .center)

                // ラベル（固定）
                Text(L.NewHome.recordLocation)
                    .font(.headline)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.9),
                                Color.accentColor.opacity(0.7)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recent Records Section

    private var recentRecordsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(L.NewHome.recentRecords)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    onViewAllTap()
                } label: {
                    Text(L.NewHome.viewAllRecords)
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 20)

            RecentRecordsCarousel(
                records: recentRecords,
                labelMap: store.labels.nameMap,
                groupMap: store.groups.nameMap,
                memberMap: store.members.nameMap,
                onUpdate: {
                    loadRecentVisits()
                }
            )
        }
    }

    private var emptyRecordsPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
                .opacity(0.5)
            Text(L.NewHome.noRecentRecords)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 40)
    }

    // MARK: - Helpers

    private var recentRecords: [VisitAggregate] {
        recentVisits ?? []
    }

    private func loadRecentVisits() {
        let repo = AppContainer.shared.repo
        do {
            // 全記録から最新3件を取得（フィルタなし、日付降順でソート）
            let allVisits = try repo.fetchAll(
                filterLabel: nil,
                filterGroup: nil,
                filterMember: nil,
                titleQuery: nil,
                dateFrom: nil,
                dateToExclusive: nil
            )
            let newRecents = Array(allVisits.sorted(by: { $0.visit.timestampUTC > $1.visit.timestampUTC }).prefix(3))

            // アニメーション付きで更新
            withAnimation {
                recentVisits = newRecents
            }
        } catch {
            Logger.error("Failed to load recent visits", error: error)
            withAnimation {
                recentVisits = []
            }
        }
    }
}

private enum MapBackgroundStyle {
    case organic
    case structured
}

private struct MapBackgroundConfig {
    let style: MapBackgroundStyle
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

private struct MapBackgroundLayer: View {
    let config: MapBackgroundConfig

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.38)
            let radius = min(size.width, size.height) * config.exclusionRadiusFactor
            // Opacity is controlled by the view modifier below.
            let strokeColor = colorScheme == .dark ? Color.white : Color.black

            let shape: AnyShape = {
                switch config.style {
                case .organic:
                    return AnyShape(
                        AbstractMapLinesPath(
                            seed: config.seed,
                            lineCount: config.organicLineCount,
                            padding: config.padding,
                            exclusionCenter: center,
                            exclusionRadius: radius
                        )
                    )
                case .structured:
                    return AnyShape(
                        AbstractMapGridPath(
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

private struct AbstractMapLinesPath: Shape {
    let seed: UInt64
    let lineCount: Int
    let padding: CGFloat
    let exclusionCenter: CGPoint
    let exclusionRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var rng = SeededRandom(state: seed)
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
        rng: inout SeededRandom
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

private struct AbstractMapGridPath: Shape {
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
        var rng = SeededRandom(state: seed)
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

private struct AnyShape: Shape {
    private let _path: (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        _path = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}

private struct SeededRandom {
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
