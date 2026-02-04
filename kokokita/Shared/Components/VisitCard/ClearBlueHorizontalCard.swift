import SwiftUI
import MapKit

/// 横型クリアブルーカードのバリアント
enum ClearBlueHorizontalVariant {
    /// 地図画面のシート用（閉じるボタンあり）
    case mapSheet
    /// ホーム画面のカルーセル用
    case carousel
}

/// 横型クリアブルー記録カード
///
/// 地図画面のシートやホーム画面のカルーセルで使用される横型カード。
/// 左側に写真サムネイル、右側にテキスト情報を表示する。
///
/// レイアウト:
/// ```
/// ┌──────────────────────────────────┐
/// │ ┌──────┐                        │
/// │ │ 写真 │ タイトル        [×]   │
/// │ │      │ 日付                   │
/// │ └──────┘ 住所                   │
/// │          [Chip] [Chip]          │
/// └──────────────────────────────────┘
/// ```
struct ClearBlueHorizontalCard: View {
    /// 表示する訪問記録
    let aggregate: VisitAggregate

    /// カードのバリアント
    var variant: ClearBlueHorizontalVariant = .carousel

    /// ラベル名のマップ
    var labelMap: [UUID: String] = [:]

    /// グループ名のマップ
    var groupMap: [UUID: String] = [:]

    /// メンバー名のマップ
    var memberMap: [UUID: String] = [:]

    /// ラベル名→色のマップ
    var labelColorMap: [String: Color] = [:]

    /// 閉じるボタンのアクション（mapSheetバリアント用）
    var onClose: (() -> Void)?

    /// カード幅（carouselバリアント用）
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

    /// 相対日付（〜日前）- carouselバリアント用
    private var relativeDate: String {
        let calendar = Calendar.current
        let now = Date()
        let date = aggregate.visit.timestampUTC

        if calendar.isDateInToday(date) {
            return L.Date.today
        }
        if calendar.isDateInYesterday(date) {
            return L.Date.yesterday
        }

        let startOfDate = calendar.startOfDay(for: date)
        let startOfNow = calendar.startOfDay(for: now)

        let components = calendar.dateComponents([.day], from: startOfDate, to: startOfNow)
        guard let days = components.day else { return "" }

        if days < 7 {
            return "\(days)日前"
        }
        if days < 28 {
            let weeks = days / 7
            return "\(weeks)週間前"
        }

        let monthComponents = calendar.dateComponents([.month], from: startOfDate, to: startOfNow)
        if let months = monthComponents.month, months > 0 {
            if months < 12 {
                return "\(months)ヶ月前"
            }
            let years = months / 12
            return "\(years)年前"
        }

        return ""
    }

    // MARK: - Body

    var body: some View {
        switch variant {
        case .mapSheet:
            mapSheetContent
        case .carousel:
            carouselContent
        }
    }

    // MARK: - Map Sheet Content

    @ViewBuilder
    private var mapSheetContent: some View {
        HStack(alignment: .top, spacing: 12) {
            // 写真（あれば）
            if !photoPaths.isEmpty {
                VisitCardPhoto(
                    paths: photoPaths,
                    size: VisitCardStyle.horizontalPhotoSize,
                    cornerRadius: VisitCardStyle.horizontalPhotoCornerRadius
                )
            }

            // テキストエリア
            VStack(alignment: .leading, spacing: 6) {
                // タイトル
                Text(displayTitle)
                    .font(.headline)
                    .foregroundStyle(VisitCardStyle.primaryTextColor)
                    .lineLimit(2)

                // 日付
                Text(formattedDate)
                    .font(VisitCardStyle.horizontalDateFont)
                    .foregroundStyle(VisitCardStyle.secondaryTextColor)

                // 住所
                if let addr = address, !addr.isEmpty {
                    Text(addr)
                        .font(VisitCardStyle.horizontalAddressFont)
                        .foregroundStyle(VisitCardStyle.secondaryTextColor)
                        .lineLimit(2)
                }

                // グループ（フォルダ帰属表示）
                if let gid = aggregate.details.groupId, let gname = groupMap[gid] {
                    GroupBadge(name: gname, compact: false)
                        .foregroundStyle(VisitCardStyle.primaryTextColor)
                }

                // ラベル/メンバー
                chipRow
            }

            Spacer()

            // 閉じるボタン
            if let onClose = onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(VisitCardStyle.primaryTextColor)
                }
            }
        }
        .padding(12)
    }

    // MARK: - Carousel Content

    @ViewBuilder
    private var carouselContent: some View {
        HStack(alignment: .center, spacing: 10) {
            // 写真エリア（常に同じスペースを確保）
            VisitCardPhoto(
                paths: photoPaths,
                size: VisitCardStyle.horizontalPhotoSize,
                cornerRadius: VisitCardStyle.horizontalPhotoCornerRadius
            )

            // テキストエリア
            VStack(alignment: .leading, spacing: 4) {
                // 相対日付
                Text(relativeDate)
                    .font(VisitCardStyle.horizontalDateFont)
                    .foregroundStyle(VisitCardStyle.secondaryTextColor)

                // タイトル
                Text(displayTitle)
                    .font(VisitCardStyle.horizontalTitleFont)
                    .foregroundStyle(VisitCardStyle.primaryTextColor)
                    .lineLimit(2)

                // 住所（常に2行分のスペースを確保）
                Text(address ?? " ")
                    .font(VisitCardStyle.horizontalAddressFont)
                    .foregroundStyle(VisitCardStyle.tertiaryTextColor)
                    .lineLimit(2)
                    .opacity(address?.isEmpty == false ? 1 : 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: cardWidth, height: VisitCardStyle.horizontalCardHeight)
        .padding(.horizontal, 12)
        .clearBlueCardStyle()
    }

    // MARK: - Chip Row

    @ViewBuilder
    private var chipRow: some View {
        let hasLabels = aggregate.details.labelIds.contains(where: { labelMap[$0] != nil })
        let hasMembers = aggregate.details.memberIds.contains(where: { memberMap[$0] != nil })
        if hasLabels || hasMembers {
            FlowRow(spacing: 6, rowSpacing: 6) {
                // ラベル（最大2つ）
                ForEach(aggregate.details.labelIds.prefix(2), id: \.self) { lid in
                    if let lname = labelMap[lid] {
                        Chip(lname, kind: .label, size: .small, showRemoveButton: false, colorDot: labelColorMap[lname])
                    }
                }
                // メンバー（最大2つ）
                ForEach(aggregate.details.memberIds.prefix(2), id: \.self) { mid in
                    if let mname = memberMap[mid] {
                        Chip(mname, kind: .member, size: .small, showRemoveButton: false)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("横型カード - カルーセル") {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 16) {
            ForEach(0..<3, id: \.self) { _ in
                ClearBlueHorizontalCard(
                    aggregate: .preview,
                    variant: .carousel
                )
            }
        }
        .padding()
    }
}

#Preview("横型カード - 地図シート") {
    ClearBlueHorizontalCard(
        aggregate: .preview,
        variant: .mapSheet,
        onClose: {}
    )
    .padding()
}
#endif
