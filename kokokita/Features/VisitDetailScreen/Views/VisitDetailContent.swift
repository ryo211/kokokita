import SwiftUI
import MapKit

struct VisitDetailContent: View {
    let data: VisitDetailData
    let mapSnapshot: UIImage?        // isSharingの時に使う
    var isSharing: Bool = false
    var nearbyVisits: [VisitAggregate] = []
    var nearbyVisitsData: [VisitDetailData] = []
    var sameGroupVisits: [VisitAggregate] = []
    var sameGroupVisitsData: [VisitDetailData] = []
    var currentGroupName: String? = nil
    var onLabelTap: ((String) -> Void)? = nil
    var onGroupTap: ((String) -> Void)? = nil
    var onMemberTap: ((String) -> Void)? = nil
    var onMapTap: (() -> Void)? = nil
    @Binding var photoFullScreenIndex: Int?

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
                        Text(data.title.ifBlank(L.Home.noTitle))
                            .font(.title2.bold())
                            .lineLimit(3)
                        if let catRaw = data.facilityCategory {
                            let category = MKPointOfInterestCategory(rawValue: catRaw)
                            Text(category.localizedName)
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
                                .onTapGesture {
                                    if !isSharing {
                                        onGroupTap?(group)
                                    }
                                }
                        }
                    }

                    // ラベル（複数あり得る）
                    if !data.labels.isEmpty {
                        FlowRow(spacing: 6, rowSpacing: 6) {
                            ForEach(data.labels, id: \.self) { name in
                                let t = name.trimmed
                                if !t.isEmpty {
                                    Chip(t, kind: .label, showRemoveButton: false)
                                        .onTapGesture {
                                            if !isSharing {
                                                onLabelTap?(t)
                                            }
                                        }
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
                                    Chip(t, kind: .member, showRemoveButton: false)
                                        .onTapGesture {
                                            if !isSharing {
                                                onMemberTap?(t)
                                            }
                                        }
                                }
                            }
                        }
                    }
                }

            }
            .padding(.horizontal)
            
            // 時刻・住所カード
            InfoCard {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "clock")
                    Text(data.timestamp.kokokitaVisitString)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }

                if let addr = data.address?.trimmed, !addr.isEmpty {
                    Divider().padding(.vertical, 6)
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "mappin.and.ellipse")
                        Text(addr)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal)

            if !data.photoPaths.isEmpty && !isSharing {
                PhotoReadOnlyGrid(paths: data.photoPaths, fullScreenIndex: $photoFullScreenIndex)
                    .padding(.horizontal, 10)
            } else if !data.photoPaths.isEmpty && isSharing {
                PhotoReadOnlyGrid(paths: data.photoPaths, fullScreenIndex: .constant(nil))
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
                    .onTapGesture {
                        onMapTap?()
                    }
                }
            }

            // メモカード
            if let memo = data.memo?.trimmed, !memo.isEmpty {
                InfoCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(L.Detail.memo, systemImage: "note.text")
                            .font(.headline)
                        Text(memo)
                            .font(.body)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)
            }

            // 近くの過去記録セクション（共有時は非表示）
            if !isSharing && !nearbyVisits.isEmpty {
                nearbyVisitsSection
                    .padding(.top, 24)  // 上のコンテンツとの距離を確保
            }

            // 同じグループの記録セクション（共有時は非表示）
            if !isSharing && !sameGroupVisits.isEmpty {
                sameGroupVisitsSection
                    .padding(.top, 24)  // 上のコンテンツとの距離を確保
            }
        }
        .padding(.bottom, 16)
        .background(
            LinearGradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    // MARK: - Nearby Visits Section

    @ViewBuilder
    private var nearbyVisitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("\(L.Detail.nearbyPastRecords)（\(nearbyVisits.count)\(L.Home.itemsCount)）", systemImage: "clock.arrow.circlepath")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(Array(nearbyVisits.enumerated()), id: \.element.visit.id) { index, visit in
                    if index < nearbyVisitsData.count {
                        NavigationLink {
                            VisitDetailScreen(
                                data: nearbyVisitsData[index],
                                visitId: visit.visit.id
                            )
                        } label: {
                            nearbyVisitRow(visit)
                        }
                        .buttonStyle(.plain)

                        // 最後以外に区切り線を追加
                        if index < nearbyVisits.count - 1 {
                            Divider()
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func nearbyVisitRow(_ visit: VisitAggregate) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                // タイトルまたは施設名
                Text(displayName(for: visit))
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                // 日付
                Text(visit.visit.timestampUTC.kokokitaVisitString)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // 住所
                if let addr = visit.details.resolvedAddress?.trimmed, !addr.isEmpty {
                    Text(addr)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }

    private func displayName(for visit: VisitAggregate) -> String {
        if let title = visit.details.title?.trimmed, !title.isEmpty {
            return title
        }
        if let facility = visit.details.facilityName?.trimmed, !facility.isEmpty {
            return facility
        }
        return L.Home.noTitle
    }

    // MARK: - Same Group Visits Section

    @ViewBuilder
    private var sameGroupVisitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                if let groupName = currentGroupName {
                    Chip(groupName, kind: .group, showRemoveButton: false)
                    Text("の他の記録（\(sameGroupVisits.count)\(L.Home.itemsCount)）")
                        .font(.headline)
                } else {
                    Text("\(L.Detail.sameGroupRecords)（\(sameGroupVisits.count)\(L.Home.itemsCount)）")
                        .font(.headline)
                }
            }
            .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(Array(sameGroupVisits.enumerated()), id: \.element.visit.id) { index, visit in
                    if index < sameGroupVisitsData.count {
                        NavigationLink {
                            VisitDetailScreen(
                                data: sameGroupVisitsData[index],
                                visitId: visit.visit.id
                            )
                        } label: {
                            nearbyVisitRow(visit)
                        }
                        .buttonStyle(.plain)

                        // 最後以外に区切り線を追加
                        if index < sameGroupVisits.count - 1 {
                            Divider()
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
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
