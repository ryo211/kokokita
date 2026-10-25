import SwiftUI
import CoreLocation

// スタンプの手動確認画面
// 未達成スポットと、条件（認識半径）を満たす過去の訪問記録の組み合わせを検出し、
// ユーザーが確認の上で任意にスタンプを獲得できるようにする
struct StampCandidateListView: View {
    @State private var candidates: [CourseRetroactiveRecognitionService.RetroactiveCandidate] = []
    @State private var isLoading = true
    // 記録候補は普段閉じておき、タップしたスポットだけ展開する
    @State private var expandedSpotIds: Set<UUID> = []
    // 獲得直後、通常記録時と同じ達成シートを表示する
    @State private var checkInResults: [CourseRecognitionService.RecognitionResult] = []
    @State private var showCheckInResult = false

    var body: some View {
        ZStack {
            CourseListBackground()

            if isLoading {
                ProgressView()
            } else if candidates.isEmpty {
                ContentUnavailableView(
                    L.Stamp.candidateListTitle,
                    systemImage: "checkmark.seal",
                    description: Text(L.Stamp.candidateEmptyDescription)
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        ForEach(candidates) { candidate in
                            let isExpanded = expandedSpotIds.contains(candidate.spot.id)
                            VStack(alignment: .leading, spacing: 10) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        toggleExpanded(candidate.spot.id)
                                    }
                                } label: {
                                    CandidateSpotHeader(
                                        course: candidate.course,
                                        spot: candidate.spot,
                                        matchCount: candidate.matchedVisits.count,
                                        isExpanded: isExpanded
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if isExpanded {
                                    ForEach(candidate.matchedVisits, id: \.visit.id) { aggregate in
                                        HStack(spacing: 10) {
                                            CheckInVisitCard(aggregate: aggregate)
                                            Spacer(minLength: 0)
                                            claimButton(course: candidate.course, spot: candidate.spot, aggregate: aggregate)
                                        }
                                    }
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle(L.Stamp.candidateListTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadCandidates()
        }
        .sheet(isPresented: $showCheckInResult) {
            CheckInResultSheet(results: checkInResults)
        }
    }

    // 記録カード(280pt固定)の右側にできる余白を使い、獲得アクションをコンパクトな丸ボタンにする
    private func claimButton(course: Course, spot: CourseSpot, aggregate: VisitAggregate) -> some View {
        Button {
            claim(course: course, spot: spot, aggregate: aggregate)
        } label: {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 22))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Color.indigo, in: Circle())
                .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L.Stamp.claimButton)
    }

    private func toggleExpanded(_ spotId: UUID) {
        if expandedSpotIds.contains(spotId) {
            expandedSpotIds.remove(spotId)
        } else {
            expandedSpotIds.insert(spotId)
        }
    }

    private func loadCandidates() async {
        do {
            candidates = try AppContainer.shared.retroactiveService.findCandidates()
        } catch {
            Logger.error("スタンプ候補の検出に失敗しました: \(error)")
        }
        isLoading = false
    }

    private func claim(course: Course, spot: CourseSpot, aggregate: VisitAggregate) {
        do {
            try AppContainer.shared.courseRepo.checkIn(spotId: spot.id, visitId: aggregate.id)
            NotificationCenter.default.post(name: .courseChanged, object: nil)
            // 獲得したスポットは候補一覧から除去する
            candidates.removeAll { $0.spot.id == spot.id }

            // 通常記録時のチェックイン判定と同じ形式の結果を組み立て、同じ達成シートを表示する
            let visit = aggregate.visit
            let distance = CLLocation(latitude: visit.latitude, longitude: visit.longitude)
                .distance(from: CLLocation(latitude: spot.latitude, longitude: spot.longitude))
            let updatedCourse = try AppContainer.shared.courseRepo.fetch(id: course.id) ?? course
            checkInResults = [CourseRecognitionService.RecognitionResult(
                course: updatedCourse,
                spot: spot,
                distanceMeters: distance,
                achievedAt: visit.timestampUTC,
                visitLatitude: visit.latitude,
                visitLongitude: visit.longitude
            )]
            showCheckInResult = true
        } catch {
            Logger.error("スタンプの獲得に失敗しました: \(error)")
        }
    }
}

// MARK: - 候補スポットのヘッダーカード（StampCardのデザイン言語を横長にアレンジ）

private struct CandidateSpotHeader: View {
    let course: Course
    let spot: CourseSpot
    let matchCount: Int
    let isExpanded: Bool

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

            // マッチ件数バッジ + 開閉シェブロン（右上）
            HStack(spacing: 3) {
                Text(L.Stamp.candidateMatchCount(matchCount))
                    .font(.caption2.bold())
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(0.25), in: Capsule())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(10)

            VStack(alignment: .leading, spacing: 2) {
                Text(course.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)

                Text(spot.name)
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.3), radius: 2)
            }
            .padding(12)
        }
        .frame(height: 92)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.indigo.opacity(0.5), lineWidth: 2)
        }
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }

    private var coverPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.indigo.opacity(0.85), Color.indigo.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 30, weight: .thin))
                .foregroundStyle(.white.opacity(0.3))
        }
    }
}
