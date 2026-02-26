import SwiftUI
import UIKit

/// タイトル末尾に記録タイプバッジをインライン表示するラベル。
///
/// `UILabel + NSTextAttachment` で描画し、幅・行数制約内でタイトルを手動省略して
/// 末尾バッジが常に表示されるようにする。
@MainActor
struct InlineRecordTypeTitle: UIViewRepresentable {
    let title: String
    let isManualEntry: Bool
    let compact: Bool
    let maxLines: Int
    let textStyle: UIFont.TextStyle
    var fontWeight: UIFont.Weight = .bold
    var textColor: UIColor = .label

    func makeUIView(context: Context) -> UILabel {
        let label = InlineBadgeLabel()
        label.isUserInteractionEnabled = false
        label.numberOfLines = maxLines == 0 ? 0 : maxLines
        label.lineBreakMode = .byClipping
        label.adjustsFontForContentSizeCategory = true
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        let baseFont = UIFont.preferredFont(forTextStyle: textStyle)
        let font = UIFont.systemFont(ofSize: baseFont.pointSize, weight: fontWeight)
        // インライン表示では行高とのバランスを優先し、過大サイズで本文が消えるのを防ぐ
        let badgeSize: CGFloat = compact ? 16 : 20
        let badgeImage = RecordTypeIconImageCache.image(
            isManualEntry: isManualEntry,
            compact: compact
        )

        guard let inlineLabel = label as? InlineBadgeLabel else {
            label.font = font
            label.textColor = textColor
            label.numberOfLines = maxLines == 0 ? 0 : maxLines
            return
        }

        inlineLabel.configure(
            title: title,
            font: font,
            textColor: textColor,
            maxLines: maxLines,
            badgeImage: badgeImage,
            badgeSize: badgeSize
        )
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
    private var inlineTitle: String = ""
    private var inlineFont: UIFont = .preferredFont(forTextStyle: .body)
    private var inlineTextColor: UIColor = .label
    private var inlineMaxLines: Int = 1
    private var inlineBadgeImage: UIImage?
    private var inlineBadgeSize: CGFloat = 16
    private var lastAppliedWidth: CGFloat = 0

    func configure(
        title: String,
        font: UIFont,
        textColor: UIColor,
        maxLines: Int,
        badgeImage: UIImage?,
        badgeSize: CGFloat
    ) {
        inlineTitle = title
        inlineFont = font
        inlineTextColor = textColor
        inlineMaxLines = maxLines
        inlineBadgeImage = badgeImage
        inlineBadgeSize = badgeSize

        self.font = font
        self.textColor = textColor
        numberOfLines = maxLines == 0 ? 0 : maxLines
        rebuildAttributedText(force: true)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        if width > 0, preferredMaxLayoutWidth != width {
            preferredMaxLayoutWidth = width
            rebuildAttributedText(force: false)
        } else if width > 0, abs(width - lastAppliedWidth) > 0.5 {
            rebuildAttributedText(force: false)
        }
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: UIView.noIntrinsicMetric, height: size.height)
    }

    private func rebuildAttributedText(force: Bool) {
        let width = bounds.width
        guard width > 0 else { return }
        if !force, abs(width - lastAppliedWidth) <= 0.5 { return }
        lastAppliedWidth = width
        attributedText = makeFittedAttributedText(width: width)
    }

    private func makeFittedAttributedText(width: CGFloat) -> NSAttributedString {
        if inlineMaxLines == 0 {
            return makeAttributed(titlePart: inlineTitle)
        }

        let allowedHeight = allowedHeightForLines(max(1, inlineMaxLines))
        let full = makeAttributed(titlePart: inlineTitle)
        if fits(full, width: width, allowedHeight: allowedHeight) {
            return full
        }

        let chars = Array(inlineTitle)
        var low = 0
        var high = chars.count
        var best = -1

        while low <= high {
            let mid = (low + high) / 2
            let candidateTitle = truncatedTitle(from: chars, prefixCount: mid)
            let candidate = makeAttributed(titlePart: candidateTitle)

            if fits(candidate, width: width, allowedHeight: allowedHeight) {
                best = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        if best >= 0 {
            return makeAttributed(titlePart: truncatedTitle(from: chars, prefixCount: best))
        }

        // 極端に狭い場合でもバッジ表示を優先
        return makeAttributed(titlePart: "")
    }

    private func truncatedTitle(from chars: [Character], prefixCount: Int) -> String {
        if prefixCount >= chars.count {
            return String(chars)
        }
        if prefixCount <= 0 {
            return "…"
        }
        let prefix = String(chars.prefix(prefixCount)).trimmingCharacters(in: .whitespacesAndNewlines)
        return prefix.isEmpty ? "…" : "\(prefix)…"
    }

    private func makeAttributed(titlePart: String) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping

        let attrs: [NSAttributedString.Key: Any] = [
            .font: inlineFont,
            .foregroundColor: inlineTextColor,
            .paragraphStyle: paragraphStyle
        ]

        let result = NSMutableAttributedString()
        if !titlePart.isEmpty {
            result.append(NSAttributedString(string: titlePart, attributes: attrs))
            result.append(NSAttributedString(string: " ", attributes: attrs))
        }

        let attachment = NSTextAttachment()
        attachment.image = inlineBadgeImage
        let midlineOffset = (inlineFont.descender + inlineFont.ascender) / 2
        let centeredYOffset = (midlineOffset - (inlineBadgeSize / 2)).rounded()
        attachment.bounds = CGRect(
            x: 0,
            y: centeredYOffset,
            width: inlineBadgeSize,
            height: inlineBadgeSize
        )
        result.append(NSAttributedString(attachment: attachment))
        return result
    }

    private func fits(_ text: NSAttributedString, width: CGFloat, allowedHeight: CGFloat) -> Bool {
        let rect = text.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return ceil(rect.height) <= allowedHeight + 0.5
    }

    private func allowedHeightForLines(_ lines: Int) -> CGFloat {
        let base = ceil(inlineFont.lineHeight * CGFloat(lines))
        let badgeOverflow = max(0, inlineBadgeSize - inlineFont.lineHeight)
        // NSTextAttachmentの描画ゆらぎ分の余裕を少し持たせる
        return base + ceil(badgeOverflow) + 2
    }
}
