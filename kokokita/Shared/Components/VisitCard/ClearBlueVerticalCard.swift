import SwiftUI
import UIKit

/// 縦型クリアブルー記録カード
///
/// 詳細画面の「近くの場所」セクションで使用される縦型カード。
/// 上部に写真サムネイル、下部にタイトル・日付・住所を表示する。
///
/// レイアウト:
/// ```
/// ┌─────────────────┐
/// │    ┌───────┐    │
/// │    │ 写真  │    │  160 x 100pt
/// │    │(1枚目)│    │
/// │    └───────┘    │
/// │                 │
/// │ タイトル        │  .subheadline.bold
/// │ 2025/01/15      │  .caption
/// │ 渋谷区神南...   │  .caption2 (2行)
/// └─────────────────┘
///      160pt
/// ```
struct ClearBlueVerticalCard: View {
    private let visitCardTitleUIColor = UIColor(named: "AccentColor") ?? .systemBlue
    /// 表示する訪問記録
    let aggregate: VisitAggregate

    /// カード幅（デフォルト: 160pt）
    var cardWidth: CGFloat = VisitCardStyle.verticalCardWidth

    /// カード高さ（デフォルト: 200pt）
    var cardHeight: CGFloat = VisitCardStyle.verticalCardHeight

    /// 写真高さ（デフォルト: 100pt）
    var photoHeight: CGFloat = VisitCardStyle.verticalPhotoHeight

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

    /// タイトル・施設名が実際に入力されているか（"タイトルなし" フォールバックでないか）
    private var hasRealTitle: Bool {
        let title = aggregate.details.title?.trimmed ?? ""
        let facility = aggregate.details.facilityName?.trimmed ?? ""
        return !title.isEmpty || !facility.isEmpty
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

    /// タイトル + 記録タイプアイコン（インライン）
    private var inlineTitleView: some View {
        InlineRecordTypeTitle(
            title: displayTitle,
            isManualEntry: aggregate.visit.isManualEntry,
            compact: true,
            maxLines: 1,
            textStyle: .subheadline,
            fontWeight: .bold,
            textColor: hasRealTitle ? visitCardTitleUIColor : visitCardTitleUIColor.withAlphaComponent(0.4)
        )
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 写真エリア（固定位置）
            VisitCardPhoto(
                paths: photoPaths,
                width: cardWidth - 16, // 左右padding分を引く
                height: photoHeight,
                cornerRadius: VisitCardStyle.verticalPhotoCornerRadius
            )
            .padding(.horizontal, 8)
            .padding(.top, 8)

            // テキストエリア（固定位置・固定高さ）
            VStack(alignment: .leading, spacing: 2) {
                // タイトル + 記録タイプアイコン（固定位置、1行）
                inlineTitleView
                    .lineLimit(1)
                    .frame(height: 20, alignment: .leading)

                // 日付（固定位置、1行）
                Text(formattedDate)
                    .font(VisitCardStyle.verticalDateFont)
                    .foregroundStyle(VisitCardStyle.secondaryTextColor)
                    .frame(height: 16, alignment: .leading)

                // 住所（固定位置、2行分のスペースを確保）
                Text(address ?? " ")
                    .font(VisitCardStyle.verticalAddressFont)
                    .foregroundStyle(VisitCardStyle.tertiaryTextColor)
                    .lineLimit(2)
                    .frame(height: 28, alignment: .topLeading)
                    .opacity(address?.isEmpty == false ? 1 : 0)
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 8)
        }
        .frame(width: cardWidth, height: cardHeight)
        .clearBlueCardStyle()
    }
}

// MARK: - Preview

#if DEBUG
#Preview("縦型クリアブルーカード") {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
            ForEach(0..<5, id: \.self) { _ in
                ClearBlueVerticalCard(
                    aggregate: .preview
                )
            }
        }
        .padding()
    }
}

// MARK: - Preview Helper

extension VisitAggregate {
    /// プレビュー用のサンプルデータ
    static var preview: VisitAggregate {
        let visitId = UUID()
        return VisitAggregate(
            id: visitId,
            visit: Visit(
                id: visitId,
                timestampUTC: Date(),
                latitude: 35.6812,
                longitude: 139.7671,
                horizontalAccuracy: 10,
                isSimulatedBySoftware: false,
                isProducedByAccessory: false,
                integrity: Visit.Integrity(
                    algo: "ES256",
                    signatureDERBase64: "",
                    publicKeyRawBase64: "",
                    payloadHashHex: "",
                    createdAtUTC: Date()
                )
            ),
            details: VisitDetails(
                title: "サンプル記録",
                facilityName: "テスト施設",
                facilityAddress: "東京都渋谷区",
                comment: "これはテストコメントです",
                resolvedAddress: "東京都渋谷区神南1-2-3"
            )
        )
    }
}
#endif
