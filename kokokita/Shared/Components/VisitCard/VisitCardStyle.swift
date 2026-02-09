import SwiftUI

/// 記録カードのスタイル種別
enum VisitCardVariant {
    /// 標準記録カード（記録一覧用）
    case standard
    /// 標準記録カード（コンパクト版、タクソノミー詳細用）
    case standardCompact
    /// 縦型クリアブルー（詳細画面「近くの場所」用）
    case clearBlueVertical
    /// 横型クリアブルー（地図シート用）
    case clearBlueMapSheet
    /// 横型クリアブルー（カルーセル用）
    case clearBlueCarousel
}

/// 記録カードの共通スタイル設定
enum VisitCardStyle {

    // MARK: - クリアブルーカード共通スタイル

    /// クリアブルーの背景色
    static let clearBlueBackground = Color.accentColor.opacity(0.08)
    /// クリアブルーのボーダー色
    static let clearBlueBorder = Color.accentColor.opacity(0.2)
    /// クリアブルーのボーダー幅
    static let clearBlueBorderWidth: CGFloat = 1
    /// クリアブルーカードの角丸
    static let clearBlueCornerRadius: CGFloat = 16

    // MARK: - 縦型カードサイズ

    /// 縦型カードの幅
    static let verticalCardWidth: CGFloat = 160
    /// 縦型カードの高さ
    static let verticalCardHeight: CGFloat = 200
    /// 縦型カードの写真高さ
    static let verticalPhotoHeight: CGFloat = 100
    /// 縦型カードの写真角丸
    static let verticalPhotoCornerRadius: CGFloat = 10

    // MARK: - 横型カードサイズ

    /// 横型カードの幅（カルーセル）
    static let horizontalCardWidth: CGFloat = 280
    /// 横型カードの高さ（固定）
    static let horizontalCardHeight: CGFloat = 100
    /// 横型カードの写真サイズ（小さめ）
    static let horizontalPhotoSize: CGFloat = 56
    /// 横型カードの写真角丸
    static let horizontalPhotoCornerRadius: CGFloat = 8

    // MARK: - シャドウ

    /// カード影（軽量）
    static let shadowLight = (
        color: Color.black.opacity(0.06),
        radius: CGFloat(2),
        x: CGFloat(0),
        y: CGFloat(1)
    )

    /// カード影（中程度）
    static let shadowMedium = (
        color: Color.black.opacity(0.12),
        radius: CGFloat(12),
        x: CGFloat(0),
        y: CGFloat(6)
    )

    /// カード影（深め）
    static let shadowDeep = (
        color: Color.black.opacity(0.08),
        radius: CGFloat(24),
        x: CGFloat(0),
        y: CGFloat(12)
    )

    // MARK: - テキストスタイル

    /// タイトルフォント（縦型）
    static let verticalTitleFont: Font = .subheadline.bold()
    /// 日付フォント（縦型）
    static let verticalDateFont: Font = .caption
    /// 住所フォント（縦型）
    static let verticalAddressFont: Font = .caption2

    /// タイトルフォント（横型）
    static let horizontalTitleFont: Font = .subheadline.bold()
    /// 日付フォント（横型）
    static let horizontalDateFont: Font = .caption
    /// 住所フォント（横型）
    static let horizontalAddressFont: Font = .caption

    // MARK: - カラー

    /// プライマリテキスト色
    static let primaryTextColor = Color.accentColor
    /// セカンダリテキスト色
    static let secondaryTextColor = Color.accentColor.opacity(0.7)
    /// ターシャリテキスト色
    static let tertiaryTextColor = Color.accentColor.opacity(0.6)
}

// MARK: - クリアブルーカード背景モディファイア

/// クリアブルーカードのスタイルを適用するViewModifier
struct ClearBlueCardModifier: ViewModifier {
    var cornerRadius: CGFloat = VisitCardStyle.clearBlueCornerRadius

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(VisitCardStyle.clearBlueBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(VisitCardStyle.clearBlueBorder, lineWidth: VisitCardStyle.clearBlueBorderWidth)
                    }
                    .shadow(
                        color: VisitCardStyle.shadowLight.color,
                        radius: VisitCardStyle.shadowLight.radius,
                        x: VisitCardStyle.shadowLight.x,
                        y: VisitCardStyle.shadowLight.y
                    )
                    .shadow(
                        color: VisitCardStyle.shadowMedium.color,
                        radius: VisitCardStyle.shadowMedium.radius,
                        x: VisitCardStyle.shadowMedium.x,
                        y: VisitCardStyle.shadowMedium.y
                    )
                    .shadow(
                        color: VisitCardStyle.shadowDeep.color,
                        radius: VisitCardStyle.shadowDeep.radius,
                        x: VisitCardStyle.shadowDeep.x,
                        y: VisitCardStyle.shadowDeep.y
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    /// クリアブルーカードスタイルを適用
    func clearBlueCardStyle(cornerRadius: CGFloat = VisitCardStyle.clearBlueCornerRadius) -> some View {
        modifier(ClearBlueCardModifier(cornerRadius: cornerRadius))
    }
}
