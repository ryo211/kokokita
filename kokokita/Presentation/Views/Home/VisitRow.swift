//
//  VisitRow.swift
//  kokokita
//
//  Created by 橋本遼 on 2025/10/05.
//

import SwiftUI
import MapKit

/// 記録一覧のセル
struct VisitRow: View {
    let agg: VisitAggregate
    let nameResolver: (_ labelIds: [UUID], _ groupId: UUID?) -> (labels: [String], group: String?)

    var body: some View {
          let names = nameResolver(agg.details.labelIds, agg.details.groupId)

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

              // ラベル／グループ名のバッジを表示
              HStack(spacing: 8) {
                  FlowRow(spacing: 6, rowSpacing: 6) {
                      if let g = names.group {
                          Chip(g, kind: .group, size: .small, showRemoveButton: false)
                      }
                      ForEach(names.labels, id: \.self) { n in
                          Chip(n, kind: .label, size: .small, showRemoveButton: false)
                      }
                  }
              }
              .padding(.top, 2)
          }
      }
  }
