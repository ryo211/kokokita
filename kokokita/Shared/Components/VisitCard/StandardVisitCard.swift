import SwiftUI
import MapKit

/// 標準記録カード
///
/// 記録一覧画面やタクソノミー詳細画面で使用される標準的なカードスタイル。
/// VisitRow.swiftの内容をコンポーネント化したもの。
///
/// バリアント:
/// - `.standard`: 記録一覧用（通常サイズ）
/// - `.compact`: タクソノミー詳細画面用（コンパクトサイズ）
struct StandardVisitCard: View {
    /// 表示する訪問記録
    let aggregate: VisitAggregate

    /// 名前解決クロージャ
    let nameResolver: (_ labelIds: [UUID], _ groupId: UUID?, _ memberIds: [UUID]) -> (labels: [String], group: String?, members: [String])

    /// コンパクトモード
    var compact: Bool = false

    // MARK: - Computed Properties

    /// 今日の記録かどうか
    private var isToday: Bool {
        Calendar.current.isDateInToday(aggregate.visit.timestampUTC)
    }

    // MARK: - Body

    var body: some View {
        let names = nameResolver(
            aggregate.details.labelIds,
            aggregate.details.groupId,
            aggregate.details.memberIds
        )

        VStack(alignment: .leading, spacing: compact ? 2 : 4) {
            // 日時
            HStack {
                Text(aggregate.visit.timestampUTC.kokokitaVisitString)
                    .font(compact ? .caption : .footnote)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            // 住所
            Text(aggregate.details.resolvedAddress ?? "")
                .font(compact ? .caption : .footnote)
                .foregroundStyle(.secondary)
                .lineLimit(compact ? 1 : 2)

            // タイトルとカテゴリ
            if let title = aggregate.details.title, !title.isEmpty {
                VStack(alignment: .leading, spacing: compact ? 1 : 2) {
                    Text(title)
                        .font(compact ? .subheadline : .headline)
                        .lineLimit(compact ? 1 : 2)

                    if let catRaw = aggregate.details.facilityCategory {
                        let category = MKPointOfInterestCategory(rawValue: catRaw)
                        Text(category.localizedName)
                            .font(compact ? .caption2 : .caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // ラベル／グループ／メンバーのバッジ
            HStack(spacing: compact ? 4 : 8) {
                FlowRow(spacing: compact ? 4 : 6, rowSpacing: compact ? 4 : 6) {
                    if let g = names.group {
                        Chip(g, kind: .group, size: compact ? .xsmall : .small, showRemoveButton: false)
                    }
                    ForEach(names.labels, id: \.self) { n in
                        Chip(n, kind: .label, size: compact ? .xsmall : .small, showRemoveButton: false)
                    }
                    ForEach(names.members, id: \.self) { n in
                        Chip(n, kind: .member, size: compact ? .xsmall : .small, showRemoveButton: false)
                    }
                }
            }
            .padding(.top, compact ? 1 : 2)
        }
    }
}

// MARK: - Convenience Initializer

extension StandardVisitCard {
    /// マップを使用した簡易初期化
    init(
        aggregate: VisitAggregate,
        labelMap: [UUID: String],
        groupMap: [UUID: String],
        memberMap: [UUID: String],
        compact: Bool = false
    ) {
        self.aggregate = aggregate
        self.compact = compact
        self.nameResolver = { labelIds, groupId, memberIds in
            let labels = labelIds.compactMap { labelMap[$0] }
            let group = groupId.flatMap { groupMap[$0] }
            let members = memberIds.compactMap { memberMap[$0] }
            return (labels, group, members)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("標準サイズ") {
    List {
        StandardVisitCard(
            aggregate: .preview,
            labelMap: [:],
            groupMap: [:],
            memberMap: [:]
        )
    }
}

#Preview("コンパクトサイズ") {
    List {
        StandardVisitCard(
            aggregate: .preview,
            labelMap: [:],
            groupMap: [:],
            memberMap: [:],
            compact: true
        )
    }
}
#endif
