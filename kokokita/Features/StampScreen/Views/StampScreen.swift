import SwiftUI

// スタンプ一覧画面（御朱印帳風）: 巡礼で達成したスポットをスタンプとして並べる
struct StampScreen: View {
    @Bindable var store: CourseListStore

    private struct AchievedStamp: Identifiable {
        let id: UUID
        let course: Course
        let spot: CourseSpot
    }

    // スタンプ詳細画面へのナビゲーション識別子（Course/CourseSpotは直接Hashableではないため）
    private struct StampNavTarget: Hashable {
        let courseId: UUID
        let spotId: UUID
    }

    // 達成済みスポットを全コース横断で集約し、達成日時が新しい順に並べる
    private var achievedStamps: [AchievedStamp] {
        var result: [AchievedStamp] = []
        for course in store.courses {
            for spot in course.spots where spot.isCheckedIn {
                result.append(AchievedStamp(id: spot.id, course: course, spot: spot))
            }
        }
        return result.sorted { lhs, rhs in
            let lhsDate: Date = lhs.spot.firstCheckedInAt ?? Date.distantPast
            let rhsDate: Date = rhs.spot.firstCheckedInAt ?? Date.distantPast
            return lhsDate > rhsDate
        }
    }

    // 手帳のマス目総数。画面が埋まる最低数（2列×3行）は常に確保しつつ、
    // 達成数が増えてもマス目が尽きないよう常に+2枚の空欄を残す
    private var totalSlotCount: Int {
        max(6, achievedStamps.count + 2)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CourseListBackground()

                ScrollView {
                    VStack(spacing: 0) {
                        header

                        if achievedStamps.isEmpty {
                            Text(L.Stamp.emptyDescription)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 32)
                                .padding(.bottom, 12)
                        }

                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)],
                            spacing: 6
                        ) {
                            ForEach(0..<totalSlotCount, id: \.self) { index in
                                if index < achievedStamps.count {
                                    let stamp = achievedStamps[index]
                                    NavigationLink(value: StampNavTarget(courseId: stamp.course.id, spotId: stamp.spot.id)) {
                                        StampCard(course: stamp.course, spot: stamp.spot)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    EmptyStampSlot()
                                }
                            }
                        }
                        .padding(.horizontal, 28)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "seal.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.indigo)
                        Text(L.Tab.stamp)
                            .font(.headline)
                    }
                }
            }
            .navigationDestination(for: StampNavTarget.self) { target in
                if let course = store.courses.first(where: { $0.id == target.courseId }),
                   let spot = course.spots.first(where: { $0.id == target.spotId }) {
                    StampDetailView(course: course, spot: spot)
                }
            }
        }
    }

    // 集めたスタンプ数を大きく見せるヘッダー（コレクション欲を刺激する）
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(achievedStamps.count)")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(.indigo)
            Text(L.Stamp.countSummarySuffix)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
}
