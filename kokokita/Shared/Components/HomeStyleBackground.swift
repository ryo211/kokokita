import SwiftUI

// ホーム画面で使っている「グラデーション + 抽象的な地図風ライン」の背景一式。
// 記録モードの他画面（記録リスト等）でも同じ雰囲気を出すために共有コンポーネント化している。

/// ホーム画面と同じ背景（グラデーション + 抽象ライン装飾）をまとめて描画する
struct HomeStyleBackground: View {
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

            MapBackgroundLayer(
                config: MapBackgroundConfig(
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

enum MapBackgroundStyle {
    case organic
    case structured
}

struct MapBackgroundConfig {
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

struct MapBackgroundLayer: View {
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

struct AbstractMapLinesPath: Shape {
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

struct AbstractMapGridPath: Shape {
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

struct AnyShape: Shape, @unchecked Sendable {
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

struct SeededRandom {
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
