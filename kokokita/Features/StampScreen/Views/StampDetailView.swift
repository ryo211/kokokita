import SwiftUI
import CoreLocation

// スタンプ詳細画面: 達成スポットの拡大表示 + 紐づく訪問記録を縦に積み重ねて表示
struct StampDetailView: View {
    let course: Course
    let spot: CourseSpot

    @State private var linkedVisits: [VisitAggregate] = []
    @State private var labelMap: [UUID: String] = [:]
    @State private var groupMap: [UUID: String] = [:]
    @State private var memberMap: [UUID: String] = [:]
    @State private var pendingUnlinkVisitId: UUID? = nil
    @State private var showUnlinkConfirm = false
    @Environment(\.dismiss) private var dismiss

    private let horizontalPadding: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            ZStack {
                CourseListBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        NavigationLink {
                            CourseDetailView(course: course, initialSelectedSpotId: spot.id)
                        } label: {
                            StampHeroCard(course: course, spot: spot)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                        // CheckInVisitCard は frame(width:) の外側に自前で
                        // .padding(.horizontal, 12) を持つため、その分(24pt)を差し引く
                        visitHistorySection(cardWidth: geo.size.width - horizontalPadding * 2 - 24)
                            .padding(.top, 10)
                            .padding(.horizontal, horizontalPadding)
                            .padding(.bottom, 24)
                    }
                }
            }
        }
        .navigationTitle(spot.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: spot.id) {
            await loadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .visitsChanged)) { _ in
            reloadLinkedVisits()
        }
        .confirmationDialog(
            L.Stamp.unlinkConfirmTitle,
            isPresented: $showUnlinkConfirm,
            titleVisibility: .visible
        ) {
            Button(L.Stamp.unlinkVisit, role: .destructive) {
                if let visitId = pendingUnlinkVisitId {
                    unlinkVisit(visitId)
                }
            }
            Button(L.Common.cancel, role: .cancel) {}
        } message: {
            Text(L.Stamp.unlinkConfirmMessage)
        }
    }

    @ViewBuilder
    private func visitHistorySection(cardWidth: CGFloat) -> some View {
        if linkedVisits.isEmpty {
            Text(L.Stamp.noVisitHistory)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 24)
        } else {
            VStack(spacing: 12) {
                ForEach(linkedVisits, id: \.visit.id) { aggregate in
                    ZStack(alignment: .topTrailing) {
                        NavigationLink {
                            VisitDetailScreen(
                                data: toDetailData(aggregate),
                                visitId: aggregate.id,
                                onBack: {},
                                onEdit: {},
                                onShare: {},
                                onDelete: {
                                    try? AppContainer.shared.repo.delete(id: aggregate.id)
                                    NotificationCenter.default.post(name: .visitsChanged, object: nil)
                                    reloadLinkedVisits()
                                },
                                onUpdate: {
                                    NotificationCenter.default.post(name: .visitsChanged, object: nil)
                                    reloadLinkedVisits()
                                },
                                onMapTap: nil
                            )
                        } label: {
                            CheckInVisitCard(aggregate: aggregate, cardWidth: cardWidth)
                        }
                        .buttonStyle(.plain)

                        Button {
                            pendingUnlinkVisitId = aggregate.id
                            showUnlinkConfirm = true
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(Color.red, in: Circle())
                                .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                        .offset(x: 4, y: -4)
                        .accessibilityLabel(L.Stamp.unlinkVisit)
                    }
                }
            }
        }
    }

    // MARK: - データ読み込み（CourseDetailView.SpotDetailExpandedView と同じロジック）

    private func loadData() async {
        let repo = AppContainer.shared.repo
        labelMap = (try? repo.allLabels())?.reduce(into: [:]) { $0[$1.id] = $1.name } ?? [:]
        groupMap = (try? repo.allGroups())?.reduce(into: [:]) { $0[$1.id] = $1.name } ?? [:]
        memberMap = (try? repo.allMembers())?.reduce(into: [:]) { $0[$1.id] = $1.name } ?? [:]
        reloadLinkedVisits()
    }

    // MARK: - スタンプの取り消し

    // spot は不変のスナップショットのため visitIds は更新されない。
    // CoreData側の解除は済んでいるので、ここでは表示中の配列から直接取り除く
    private func unlinkVisit(_ visitId: UUID) {
        do {
            try AppContainer.shared.courseRepo.unlinkVisit(spotId: spot.id, visitId: visitId)
            NotificationCenter.default.post(name: .courseChanged, object: nil)
            linkedVisits.removeAll { $0.visit.id == visitId }
            if linkedVisits.isEmpty {
                dismiss()
            }
        } catch {
            Logger.error("スタンプの取り消しに失敗しました: \(error)")
        }
    }

    private func reloadLinkedVisits() {
        guard !spot.visitIds.isEmpty else {
            linkedVisits = []
            return
        }
        linkedVisits = spot.visitIds.compactMap { id in
            try? AppContainer.shared.repo.get(by: id)
        }
    }

    private func toDetailData(_ agg: VisitAggregate) -> VisitDetailData {
        let title: String = {
            let t = agg.details.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let t, !t.isEmpty { return t }
            if let f = agg.details.facilityName, !f.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return f }
            return L.Home.noTitle
        }()

        let coord: CLLocationCoordinate2D? = {
            let lat = agg.visit.latitude
            let lon = agg.visit.longitude
            guard lat != 0 || lon != 0 else { return nil }
            return .init(latitude: lat, longitude: lon)
        }()

        return VisitDetailData(
            title: title,
            labels: agg.details.labelIds.compactMap { labelMap[$0] },
            group: agg.details.groupId.flatMap { groupMap[$0] },
            members: agg.details.memberIds.compactMap { memberMap[$0] },
            timestamp: agg.visit.timestampUTC,
            address: agg.details.resolvedAddress ?? agg.details.facilityAddress,
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
}

// MARK: - 拡大版スタンプカード

private struct StampHeroCard: View {
    let course: Course
    let spot: CourseSpot

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            courseCoverImage(
                localPath: spot.localCoverImagePath,
                remoteURLString: spot.coverImageUrl,
                placeholder: { coverPlaceholder }
            )

            LinearGradient(
                colors: [Color.black.opacity(0.05), Color.black.opacity(0.30), Color.black.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )

            // ハンコ（グリッドカードより大きく、存在感のある押し方に）
            // 面の下地だと「シール」に見えるため、線の輪郭にだけ白い縁取りを重ねて視認性を確保する
            Image("kokokita_hanko")
                .resizable()
                .scaledToFit()
                .frame(width: 152, height: 152)
                .shadow(color: .white.opacity(0.6), radius: 1.6)
                .shadow(color: .white.opacity(0.6), radius: 1.6)
                .shadow(color: .white.opacity(0.4), radius: 4)
                .rotationEffect(.degrees(-11))
                .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 14)
                .padding(.trailing, -6)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "map.fill")
                        .font(.caption)
                    Text(course.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(.white.opacity(0.8))

                Text(spot.name)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.3), radius: 3)

                if let achievedAt = spot.firstCheckedInAt {
                    Text(achievedAt, format: .dateTime.year().month().day())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.22), in: Capsule())
                }
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fill)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.indigo.opacity(0.6), lineWidth: 3)
        }
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 6)
    }

    private var coverPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.indigo.opacity(0.85), Color.indigo.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 60, weight: .thin))
                .foregroundStyle(.white.opacity(0.3))
        }
    }
}
