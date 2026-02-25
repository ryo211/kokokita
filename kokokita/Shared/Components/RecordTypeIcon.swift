import SwiftUI

/// 記録タイプバッジ
///
/// 通常記録と後付け記録を区別するバッジ。
/// ココキタボタン・追加ボタンのデザインを踏襲。
/// - 証明付き記録：青い丸にココキタアイコン（白）
/// - 後付け記録：オレンジの丸にココキタアイコン（白）
struct RecordTypeIcon: View {
    let isManualEntry: Bool
    var compact: Bool = false

    /// バッジサイズ
    private var badgeSize: CGFloat {
        compact ? 16 : 20
    }

    /// アイコンサイズ
    private var iconSize: CGFloat {
        compact ? 10 : 12
    }

    /// バッジの色
    private var badgeColor: Color {
        isManualEntry ? .orange : .accentColor
    }

    /// テキストのベースラインに対する見た目の縦位置補正
    ///
    /// SwiftUIのベースライン揃えでは、非テキストViewはやや上に見えやすいため、
    /// バッジの基準点を少し上にして実際の表示位置を下げる。
    private var baselineCorrection: CGFloat {
        compact ? 2 : 3
    }

    var body: some View {
        ZStack {
            // バッジ風背景（グラデーション＋シャドウ）
            RecordTypeBadgeShape()
                .fill(
                    LinearGradient(
                        colors: [
                            badgeColor.opacity(0.95),
                            badgeColor.opacity(0.75)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RecordTypeBadgeShape()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.25),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .overlay {
                    RecordTypeBadgeShape()
                        .stroke(Color.white.opacity(0.28), lineWidth: 0.8)
                }
                .frame(width: badgeSize, height: badgeSize)
                .shadow(color: badgeColor.opacity(0.3), radius: 2, x: 0, y: 1)

            // ココキタアイコン（白）
            Image("kokokita_irodori_white")
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .offset(y: compact ? -0.8 : -1.0)
        }
        .alignmentGuide(.firstTextBaseline) { d in
            d[.bottom] - baselineCorrection
        }
        .alignmentGuide(.lastTextBaseline) { d in
            d[.bottom] - baselineCorrection
        }
    }
}

private struct RecordTypeBadgeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseRadius = min(rect.width, rect.height) * 0.42
        let spikeRadius = baseRadius * 1.2
        let points = 8

        var path = Path()
        for i in 0..<(points * 2) {
            let angle = (-Double.pi / 2) + (Double(i) * Double.pi / Double(points))
            let radius = (i % 2 == 0) ? spikeRadius : baseRadius
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )

            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack {
            Text("証明付き記録（青）")
            RecordTypeIcon(isManualEntry: false)
        }
        HStack {
            Text("後付け記録（オレンジ）")
            RecordTypeIcon(isManualEntry: true)
        }
        HStack {
            Text("証明付き記録（コンパクト）")
            RecordTypeIcon(isManualEntry: false, compact: true)
        }
        HStack {
            Text("後付け記録（コンパクト）")
            RecordTypeIcon(isManualEntry: true, compact: true)
        }
    }
    .padding()
}
