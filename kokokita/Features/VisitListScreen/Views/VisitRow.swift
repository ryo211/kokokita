import SwiftUI
import MapKit

/// 記録一覧のセル
struct VisitRow: View {
    let agg: VisitAggregate
    let nameResolver: (_ labelIds: [UUID], _ groupId: UUID?, _ memberIds: [UUID]) -> (labels: [String], group: String?, members: [String])

    var body: some View {
          let names = nameResolver(agg.details.labelIds, agg.details.groupId, agg.details.memberIds)

          VStack(alignment: .leading, spacing: 4) {
              HStack {
                  Text(agg.visit.timestampUTC.kokokitaVisitString)
                      .font(.footnote)
                      .foregroundStyle(.secondary)
                  Spacer()
              }
              Text(agg.details.resolvedAddress ?? "")
                  .font(.footnote)
                  .foregroundStyle(.secondary)

              if let title = agg.details.title, !title.isEmpty {
                  VStack(alignment: .leading, spacing: 2) {
                      Text(title)
                          .font(.headline)
                      if let catRaw = agg.details.facilityCategory {
                          let category = MKPointOfInterestCategory(rawValue: catRaw)
                          Text(category.japaneseName)
                              .font(.caption)
                              .foregroundStyle(.secondary)
                      }
                  }
              }

              // ラベル／グループ／メンバー名のバッジを表示
              HStack(spacing: 8) {
                  FlowRow(spacing: 6, rowSpacing: 6) {
                      if let g = names.group {
                          Chip(g, kind: .group, size: .small, showRemoveButton: false)
                      }
                      ForEach(names.labels, id: \.self) { n in
                          Chip(n, kind: .label, size: .small, showRemoveButton: false)
                      }
                      ForEach(names.members, id: \.self) { n in
                          HStack(spacing: 3) {
                              Image(systemName: "person")
                                  .font(.system(size: 9))
                              Text(n)
                                  .font(.system(size: 11))
                          }
                          .padding(.horizontal, 7)
                          .padding(.vertical, 4)
                          .background(Color.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                      }
                  }
              }
              .padding(.top, 2)
          }
      }
  }
