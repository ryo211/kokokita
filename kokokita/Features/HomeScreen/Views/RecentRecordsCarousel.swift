import SwiftUI
import CoreLocation

/// ホーム画面の「最近の記録」カルーセル
///
/// 横型クリアブルーカード（写真付き）を横スクロールで表示
struct RecentRecordsCarousel: View {
    let records: [VisitAggregate]
    let labelMap: [UUID: String]
    let groupMap: [UUID: String]
    let memberMap: [UUID: String]
    var labelColorMap: [String: Color] = [:]
    let onUpdate: () -> Void

    @Environment(AppUIState.self) private var ui
    @State private var editingTarget: VisitAggregate? = nil

    var body: some View {
        Group {
            if #available(iOS 17, *) {
                ios17Carousel
            } else {
                ios16Carousel
            }
        }
        .sheet(item: $editingTarget) { visit in
            NavigationStack {
                EditView(aggregate: visit) {
                    editingTarget = nil
                    onUpdate()
                }
            }
        }
    }

    // MARK: - iOS 17+ Implementation

    @available(iOS 17, *)
    private var ios17Carousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(records) { agg in
                    NavigationLink {
                        VisitDetailScreen(
                            data: toDetailData(agg),
                            visitId: agg.id,
                            onBack: {},
                            onEdit: { editingTarget = agg },
                            onShare: {},
                            onDelete: {
                                deleteVisit(id: agg.id)
                                onUpdate()
                            },
                            onUpdate: {
                                onUpdate()
                            },
                            onMapTap: { ui.mapFocusVisitId = agg.id }
                        )
                    } label: {
                        ClearBlueHorizontalCard(
                            aggregate: agg,
                            variant: .carousel,
                            labelMap: labelMap,
                            groupMap: groupMap,
                            memberMap: memberMap,
                            labelColorMap: labelColorMap
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 20)
            .padding(.top, 0)
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollClipDisabled()
        .frame(height: VisitCardStyle.horizontalCardHeight + 20)
    }

    // MARK: - iOS 16 Fallback

    private var ios16Carousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(records) { agg in
                    NavigationLink {
                        VisitDetailScreen(
                            data: toDetailData(agg),
                            visitId: agg.id,
                            onBack: {},
                            onEdit: { editingTarget = agg },
                            onShare: {},
                            onDelete: {
                                deleteVisit(id: agg.id)
                                onUpdate()
                            },
                            onUpdate: {
                                onUpdate()
                            },
                            onMapTap: { ui.mapFocusVisitId = agg.id }
                        )
                    } label: {
                        ClearBlueHorizontalCard(
                            aggregate: agg,
                            variant: .carousel,
                            labelMap: labelMap,
                            groupMap: groupMap,
                            memberMap: memberMap,
                            labelColorMap: labelColorMap
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 0)
        }
        .frame(height: VisitCardStyle.horizontalCardHeight + 20)
    }

    // MARK: - Helper

    private func toDetailData(_ agg: VisitAggregate) -> VisitDetailData {
        let title: String = {
            let t = agg.details.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let t, !t.isEmpty { return t }
            if let f = agg.details.facilityName, !f.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return f }
            return L.Home.noTitle
        }()

        let labels: [String] = agg.details.labelIds.compactMap { labelMap[$0] }
        let group: String? = agg.details.groupId.flatMap { groupMap[$0] }
        let members: [String] = agg.details.memberIds.compactMap { memberMap[$0] }

        let coord: CLLocationCoordinate2D? = {
            let lat = agg.visit.latitude
            let lon = agg.visit.longitude
            if lat == 0 && lon == 0 { return nil }
            return .init(latitude: lat, longitude: lon)
        }()

        let address = agg.details.resolvedAddress ?? agg.details.facilityAddress

        return VisitDetailData(
            title: title,
            labels: labels,
            group: group,
            members: members,
            timestamp: agg.visit.timestampUTC,
            address: address,
            coordinate: coord,
            memo: agg.details.comment,
            facility: FacilityInfo(
                name: agg.details.facilityName,
                address: agg.details.facilityAddress,
                phone: nil
            ),
            facilityCategory: agg.details.facilityCategory,
            photoPaths: agg.details.photoPaths,
            isManualEntry: agg.visit.isManualEntry
        )
    }

    private func deleteVisit(id: UUID) {
        let repo = AppContainer.shared.repo
        do {
            try repo.delete(id: id)
            NotificationCenter.default.post(name: .visitsChanged, object: nil)
        } catch {
            Logger.error("Failed to delete visit from home carousel", error: error)
        }
    }
}
