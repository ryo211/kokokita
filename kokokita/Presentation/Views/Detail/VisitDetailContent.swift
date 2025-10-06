//
//  VisitDetailContent.swift
//  kokokita
//
//  Created by 橋本遼 on 2025/10/05.
//

// VisitDetailContent.swift
import SwiftUI
import MapKit

struct VisitDetailContent: View {
    let data: VisitDetailData
    let mapSnapshot: UIImage?        // isSharingの時に使う
    var isSharing: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // タイトル + ラベル/グループ（くっつくイメージ）
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(data.title.ifBlank("（タイトルなし）"))
                        .font(.title2.bold())
                        .lineLimit(3)
                    FacilityInfoButton(
                        name: data.facility?.name,
                        address: data.facility?.address,
                        phone: data.facility?.phone,
                        mode: .readOnly                // 閲覧用。クリアは出ない
                    )
                }

                VStack(alignment: .leading, spacing: 6) {
                    // グループ（1行）
                    if let group = data.group?.trimmed, !group.isEmpty {
                        FlowRow(spacing: 6, rowSpacing: 6) {
                            Chip(group, kind: .group, showRemoveButton: false)
                        }
                    }

                    // ラベル（複数あり得る）
                    if !data.labels.isEmpty {
                        FlowRow(spacing: 6, rowSpacing: 6) {
                            ForEach(data.labels, id: \.self) { name in
                                let t = name.trimmed
                                if !t.isEmpty {
                                    Chip(t, kind: .label, showRemoveButton: false)
                                }
                            }
                        }
                    }
                }

            }
            .padding(.horizontal)

            // 時刻・住所カード
            InfoCard {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "clock")
                    VStack(alignment: .leading, spacing: 4) {
                        Text(data.timestamp.kokokitaVisitString)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }

                if let addr = data.address?.trimmed, !addr.isEmpty {
                    Divider().padding(.vertical, 6)
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "mappin.and.ellipse")
                        VStack(alignment: .leading, spacing: 4) {
                            Text(addr)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal)

            // 地図カード
            if isSharing {
                if let img = mapSnapshot {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 300)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            } else {
                if let c = data.coordinate {
                    InfoCard(padding: 0) {
                        MapPreview(
                            lat: c.latitude,
                            lon: c.longitude,
                            showCoordinateOverlay: true,
                            decimals: 5
                        )
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal)
                }
            }

            // メモカード
            if let memo = data.memo?.trimmed, !memo.isEmpty {
                InfoCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("メモ", systemImage: "note.text")
                            .font(.headline)
                        Text(memo)
                            .font(.body)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 16)
        .background(
            LinearGradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                           startPoint: .top, endPoint: .bottom)
        )
    }
}


struct InfoCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(padding)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}
