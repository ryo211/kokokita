import SwiftUI
import UIKit

/// チェックイン済みスポットに紐づいた記録カード
///
/// コース詳細画面のスポット展開エリアで使用される横型カード。
/// 日付・住所・タイトルの順で表示する（コース文脈における時系列重視のレイアウト）。
///
/// レイアウト:
/// ```
/// ┌──────────────────────────────────┐
/// │ ┌──────┐ 2025/01/15            │
/// │ │ 写真 │ 東京都渋谷区神南...    │
/// │ └──────┘ サンプル記録           │
/// └──────────────────────────────────┘
///             280pt x 100pt
/// ```
struct CheckInVisitCard: View {
    private let visitCardTitleUIColor = UIColor(named: "AccentColor") ?? .systemBlue

    let aggregate: VisitAggregate

    /// カード幅（デフォルト: 280pt）
    var cardWidth: CGFloat = VisitCardStyle.horizontalCardWidth

    // MARK: - Computed Properties

    /// 表示用タイトル
    private var displayTitle: String {
        if let title = aggregate.details.title?.trimmed, !title.isEmpty {
            return title
        }
        if let facility = aggregate.details.facilityName?.trimmed, !facility.isEmpty {
            return facility
        }
        return L.Home.noTitle
    }

    /// フォーマットされた日付文字列
    private var formattedDate: String {
        aggregate.visit.timestampUTC.kokokitaVisitString
    }

    /// 住所
    private var address: String? {
        aggregate.details.resolvedAddress?.trimmed
    }

    /// 写真パス
    private var photoPaths: [String] {
        aggregate.details.photoPaths
    }

    // MARK: - Body

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // 写真エリア（常に同じスペースを確保）
            VisitCardPhoto(
                paths: photoPaths,
                size: VisitCardStyle.horizontalPhotoSize,
                cornerRadius: VisitCardStyle.horizontalPhotoCornerRadius
            )

            // テキストエリア（日付→住所→タイトルの順）
            VStack(alignment: .leading, spacing: 3) {
                // 日付
                Text(formattedDate)
                    .font(VisitCardStyle.horizontalDateFont)
                    .foregroundStyle(VisitCardStyle.secondaryTextColor)
                    .lineLimit(1)

                // 住所
                Text(address ?? " ")
                    .font(VisitCardStyle.horizontalAddressFont)
                    .foregroundStyle(VisitCardStyle.tertiaryTextColor)
                    .lineLimit(1)
                    .opacity(address?.isEmpty == false ? 1 : 0)

                // タイトル + 記録タイプアイコン
                InlineRecordTypeTitle(
                    title: displayTitle,
                    isManualEntry: aggregate.visit.isManualEntry,
                    compact: true,
                    maxLines: 1,
                    textStyle: .subheadline,
                    fontWeight: .bold,
                    textColor: visitCardTitleUIColor
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: cardWidth, height: VisitCardStyle.horizontalCardHeight)
        .padding(.horizontal, 12)
        .clearBlueCardStyle()
    }
}

// MARK: - Preview

#if DEBUG
#Preview("チェックイン記録カード") {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 16) {
            ForEach(0..<3, id: \.self) { _ in
                CheckInVisitCard(aggregate: .preview)
            }
        }
        .padding()
    }
}
#endif
