import SwiftUI
import CoreLocation

struct RecentRecordsCarousel: View {
    let records: [VisitAggregate]
    let labelMap: [UUID: String]
    let groupMap: [UUID: String]
    let memberMap: [UUID: String]
    let onUpdate: () -> Void

    var body: some View {
        if #available(iOS 17, *) {
            ios17Carousel
        } else {
            ios16Carousel
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
                            onEdit: {},
                            onShare: {},
                            onDelete: {
                                deleteVisit(id: agg.id)
                                onUpdate()
                            },
                            onUpdate: {
                                onUpdate()
                            },
                            onMapTap: nil
                        )
                    } label: {
                        carouselCard(for: agg)
                    }
                    .buttonStyle(.plain)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 20)
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollClipDisabled()
        .frame(height: 120)
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
                            onEdit: {},
                            onShare: {},
                            onDelete: {
                                deleteVisit(id: agg.id)
                                onUpdate()
                            },
                            onUpdate: {
                                onUpdate()
                            },
                            onMapTap: nil
                        )
                    } label: {
                        carouselCard(for: agg)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 120)
    }

    // MARK: - Card Component

    private func carouselCard(for agg: VisitAggregate) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // 相対日付（〜日前）
            Text(relativeDate(for: agg.visit.timestampUTC))
                .font(.caption)
                .foregroundStyle(.secondary)

            // タイトル
            Text(displayTitle(for: agg))
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
                .lineLimit(2)

            // 住所
            if let address = agg.details.resolvedAddress?.trimmed, !address.isEmpty {
                Text(address)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(width: 280, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial)
                .overlay {
                    // ハイライトのリムライト（液体ガラス感）
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.65),
                                    Color.white.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                }
                .overlay {
                    // 面のゆるい反射
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.28),
                                    Color.white.opacity(0.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .blendMode(.screen)
                }
                .overlay {
                    // 角のきらっと感
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.32),
                                    Color.clear
                                ],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 160
                            )
                        )
                        .blendMode(.screen)
                }
                .overlay {
                    // うっすら色味を乗せてガラス感を強調
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.8))
                }
                .shadow(color: Color.black.opacity(0.24), radius: 28, x: 0, y: 16)
                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
                .shadow(color: Color.white.opacity(0.45), radius: 14, x: 0, y: -10)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func relativeDate(for date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        // 今日
        if calendar.isDateInToday(date) {
            return "今日"
        }

        // 昨日
        if calendar.isDateInYesterday(date) {
            return "昨日"
        }

        // 日付を0時0分0秒に正規化
        let startOfDate = calendar.startOfDay(for: date)
        let startOfNow = calendar.startOfDay(for: now)

        let components = calendar.dateComponents([.day], from: startOfDate, to: startOfNow)
        guard let days = components.day else { return "最近" }


        // 2-6日前
        if days < 7 {
            return "\(days)日前"
        }

        // 7-27日前（週単位）
        if days < 28 {
            let weeks = days / 7
            return "\(weeks)週間前"
        }

        // 28日以上（月単位）
        let monthComponents = calendar.dateComponents([.month], from: startOfDate, to: startOfNow)
        if let months = monthComponents.month, months > 0 {
            if months < 12 {
                return "\(months)ヶ月前"
            } else {
                let years = months / 12
                return "\(years)年前"
            }
        }

        return "最近"
    }

    private func displayTitle(for agg: VisitAggregate) -> String {
        if let title = agg.details.title?.trimmed, !title.isEmpty {
            return title
        }
        if let facility = agg.details.facilityName?.trimmed, !facility.isEmpty {
            return facility
        }
        return L.Home.noTitle
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
            photoPaths: agg.details.photoPaths
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
