import SwiftUI
import MapKit
import UIKit

/// 記録一覧のセル
struct VisitRow: View {
    let agg: VisitAggregate
    let nameResolver: (_ labelIds: [UUID], _ groupId: UUID?, _ memberIds: [UUID]) -> (labels: [String], group: String?, members: [String])
    var compact: Bool = false  // コンパクトモード
    var showPhoto: Bool = true  // 写真表示（一覧画面で使用）
    var labelColorMap: [String: Color] = [:]  // ラベル名→色のマップ

    /// サムネイルサイズ（小さめに設定）
    private var photoSize: CGFloat {
        compact ? 32 : 36
    }

    /// 写真があるかどうか
    private var hasPhoto: Bool {
        !agg.details.photoPaths.isEmpty
    }

    // 今日の記録かどうかを判定
    private var isToday: Bool {
        Calendar.current.isDateInToday(agg.visit.timestampUTC)
    }

    var body: some View {
        let names = nameResolver(agg.details.labelIds, agg.details.groupId, agg.details.memberIds)

        VStack(alignment: .leading, spacing: compact ? 2 : 4) {
            // 日時
            Text(agg.visit.timestampUTC.kokokitaVisitString)
                .font(compact ? .caption : .footnote)
                .foregroundStyle(.secondary)

            // 住所
            Text(agg.details.resolvedAddress ?? "")
                .font(compact ? .caption : .footnote)
                .foregroundStyle(.secondary)
                .lineLimit(compact ? 1 : 2)

            // タイトル・カテゴリ + 記録タイプアイコン
            if let title = agg.details.title, !title.isEmpty {
                VStack(alignment: .leading, spacing: compact ? 1 : 2) {
                    InlineRecordTypeTitle(
                        title: title,
                        isManualEntry: agg.visit.isManualEntry,
                        compact: compact,
                        maxLines: compact ? 1 : 2
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if let catRaw = agg.details.facilityCategory {
                        let category = MKPointOfInterestCategory(rawValue: catRaw)
                        Text(category.localizedName)
                            .font(compact ? .caption2 : .caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                // タイトルがない場合は住所の後にアイコンを表示
                RecordTypeIcon(isManualEntry: agg.visit.isManualEntry, compact: compact)
            }

            // グループ（フォルダ帰属表示）
            if let g = names.group {
                GroupBadge(name: g, compact: compact)
            }

            // ラベル／メンバー名のバッジを表示
            if !names.labels.isEmpty || !names.members.isEmpty {
                FlowRow(spacing: compact ? 4 : 6, rowSpacing: compact ? 4 : 6) {
                    ForEach(names.labels, id: \.self) { n in
                        Chip(n, kind: .label, size: compact ? .xsmall : .small, showRemoveButton: false, colorDot: labelColorMap[n])
                    }
                    ForEach(names.members, id: \.self) { n in
                        Chip(n, kind: .member, size: compact ? .xsmall : .small, showRemoveButton: false)
                    }
                }
                .padding(.top, compact ? 1 : 2)
            }

            // 写真サムネイル（一番下に横一列で表示）
            if showPhoto && hasPhoto {
                HStack(spacing: 6) {
                    ForEach(agg.details.photoPaths, id: \.self) { path in
                        AsyncThumbnailImage(
                            path: path,
                            size: CGSize(width: photoSize, height: photoSize),
                            cornerRadius: 6
                        )
                    }
                }
                .padding(.top, compact ? 2 : 4)
            }
        }
    }
}

@MainActor
private struct InlineRecordTypeTitle: UIViewRepresentable {
    let title: String
    let isManualEntry: Bool
    let compact: Bool
    let maxLines: Int

    func makeUIView(context: Context) -> UILabel {
        let label = InlineBadgeLabel()
        label.numberOfLines = maxLines
        label.lineBreakMode = .byTruncatingTail
        label.adjustsFontForContentSizeCategory = true
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        let textStyle: UIFont.TextStyle = compact ? .subheadline : .headline
        let font = UIFont.preferredFont(forTextStyle: textStyle)
        label.font = font
        label.textColor = UIColor.label
        label.numberOfLines = maxLines

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.label
        ]
        let result = NSMutableAttributedString(string: title, attributes: attrs)
        result.append(NSAttributedString(string: " ", attributes: attrs))

        let attachment = NSTextAttachment()
        attachment.image = RecordTypeIconImageCache.image(isManualEntry: isManualEntry, compact: compact)
        let badgeSize: CGFloat = compact ? 16 : 20
        attachment.bounds = CGRect(
            x: 0,
            y: compact ? -2 : -3,
            width: badgeSize,
            height: badgeSize
        )
        result.append(NSAttributedString(attachment: attachment))

        label.attributedText = result
    }
}

@MainActor
private enum RecordTypeIconImageCache {
    static func image(isManualEntry: Bool, compact: Bool) -> UIImage? {
        let key = "\(isManualEntry)-\(compact)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let badgeSize: CGFloat = compact ? 16 : 20
        let renderer = ImageRenderer(
            content: RecordTypeIcon(isManualEntry: isManualEntry, compact: compact)
                .frame(width: badgeSize, height: badgeSize)
        )
        renderer.scale = UIScreen.main.scale
        guard let uiImage = renderer.uiImage else { return nil }
        cache.setObject(uiImage, forKey: key)
        return uiImage
    }

    private static let cache = NSCache<NSString, UIImage>()
}

private final class InlineBadgeLabel: UILabel {
    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        if width > 0, preferredMaxLayoutWidth != width {
            preferredMaxLayoutWidth = width
        }
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: UIView.noIntrinsicMetric, height: size.height)
    }
}
