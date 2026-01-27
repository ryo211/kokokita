import SwiftUI
import MapKit

/// 記録一覧のセル
struct VisitRow: View {
    let agg: VisitAggregate
    let nameResolver: (_ labelIds: [UUID], _ groupId: UUID?, _ memberIds: [UUID]) -> (labels: [String], group: String?, members: [String])
    var compact: Bool = false  // コンパクトモード

    var body: some View {
          let names = nameResolver(agg.details.labelIds, agg.details.groupId, agg.details.memberIds)

          VStack(alignment: .leading, spacing: compact ? 2 : 4) {
              HStack {
                  Text(agg.visit.timestampUTC.kokokitaVisitString)
                      .font(compact ? .caption : .footnote)
                      .foregroundStyle(.secondary)
                  Spacer()
              }
              Text(agg.details.resolvedAddress ?? "")
                  .font(compact ? .caption : .footnote)
                  .foregroundStyle(.secondary)
                  .lineLimit(compact ? 1 : 2)

              if let title = agg.details.title, !title.isEmpty {
                  VStack(alignment: .leading, spacing: compact ? 1 : 2) {
                      Text(title)
                          .font(compact ? .subheadline : .headline)
                          .lineLimit(compact ? 1 : 2)
                      if let catRaw = agg.details.facilityCategory {
                          let category = MKPointOfInterestCategory(rawValue: catRaw)
                          Text(category.localizedName)
                              .font(compact ? .caption2 : .caption)
                              .foregroundStyle(.secondary)
                      }
                  }
              }

              // ラベル／グループ／メンバー名のバッジを表示
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
