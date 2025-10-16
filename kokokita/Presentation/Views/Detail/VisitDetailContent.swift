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
        VStack(alignment: .leading, spacing: UIConstants.Spacing.large) {
            // 共有画像の場合、最上部にロゴを表示
            if isSharing {
                KokokitaHeaderLogo(size: .small)
                    .opacity(0.8)
                    .fixedSize()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, UIConstants.Spacing.medium)
                    .padding(.bottom, UIConstants.Spacing.small)
            }

            // タイトル + ラベル/グループ（くっつくイメージ）
            VStack(alignment: .leading, spacing: UIConstants.Spacing.medium) {
                HStack(spacing: UIConstants.Spacing.medium) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(data.title.ifBlank("（タイトルなし）"))
                            .font(.title2.bold())
                            .lineLimit(3)
                        if let catRaw = data.facilityCategory {
                            let category = MKPointOfInterestCategory(rawValue: catRaw)
                            Text(category.japaneseName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                    FacilityInfoButton(
                        name: data.facility?.name,
                        address: data.facility?.address,
                        phone: data.facility?.phone,
                        categoryRawValue: data.facilityCategory,
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

                    // メンバー（複数あり得る）
                    if !data.members.isEmpty {
                        FlowRow(spacing: 6, rowSpacing: 6) {
                            ForEach(data.members, id: \.self) { name in
                                let t = name.trimmed
                                if !t.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "person")
                                            .font(.caption2)
                                        Text(t)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
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

            if !data.photoPaths.isEmpty {
                PhotoReadOnlyGrid(paths: data.photoPaths)
                    .padding(.horizontal, 10)
            }
            
            // 地図カード
            if isSharing {
                if let img = mapSnapshot {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(height: UIConstants.Size.shareMapHeight)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: AppConfig.mapCornerRadius))
                }
            } else {
                if let c = data.coordinate {
                    InfoCard(padding: 0) {
                        MapPreview(
                            lat: c.latitude,
                            lon: c.longitude,
                            showCoordinateOverlay: true
                        )
                        .frame(height: UIConstants.Size.mapPreviewHeight)
                        .clipShape(RoundedRectangle(cornerRadius: UIConstants.CornerRadius.large))
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
    var padding: CGFloat = UIConstants.Padding.infoCard
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: UIConstants.Spacing.large) {
                content
            }
            .padding(padding)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: UIConstants.CornerRadius.large, style: .continuous))
        .shadow(color: Color.black.opacity(UIConstants.Alpha.subtleHighlight),
                radius: UIConstants.Shadow.radiusLarge,
                x: 0,
                y: UIConstants.Shadow.offsetYLarge)
    }
}
