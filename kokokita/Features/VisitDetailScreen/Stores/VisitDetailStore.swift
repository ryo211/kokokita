import Foundation
import Observation
import SwiftUI

/// 詳細画面の状態管理とビジネスロジックを担当するStore
@MainActor
@Observable
final class VisitDetailStore {
    // MARK: - タクソノミーデータ
    var labelOptions: [LabelTag] = []
    var groupOptions: [GroupTag] = []
    var memberOptions: [MemberTag] = []

    // MARK: - 近くの過去記録
    var nearbyVisits: [VisitAggregate] = []
    var nearbyVisitsData: [VisitDetailData] = []

    // MARK: - 同じグループの記録
    var sameGroupVisits: [VisitAggregate] = []
    var sameGroupVisitsData: [VisitDetailData] = []
    var currentGroupName: String? = nil

    // MARK: - タクソノミー選択（詳細画面遷移用）
    var selectedLabel: LabelTag? = nil
    var selectedGroup: GroupTag? = nil
    var selectedMember: MemberTag? = nil

    /// ラベル名 -> 色のマップ（labelOptions から構築）
    var labelColorMap: [String: Color] { labelOptions.colorMap }

    // MARK: - コース到達の順位（「◯人目」表示）
    var courseArrivalInfo: [CourseArrivalRankInfo] = []

    // MARK: - 依存
    private let repo: CoreDataVisitRepository
    private let spotArrivalOutboxRepo: SpotArrivalOutboxRepository
    private let courseRepo: CourseRepository

    init(
        repo: CoreDataVisitRepository = AppContainer.shared.repo,
        spotArrivalOutboxRepo: SpotArrivalOutboxRepository = AppContainer.shared.spotArrivalOutboxRepo,
        courseRepo: CourseRepository = AppContainer.shared.courseRepo
    ) {
        self.repo = repo
        self.spotArrivalOutboxRepo = spotArrivalOutboxRepo
        self.courseRepo = courseRepo
    }

    // MARK: - データロード

    /// タクソノミー（ラベル・グループ・メンバー）を読み込む
    func loadTaxonomyData() async {
        labelOptions = ((try? repo.allLabels()) ?? []).excludingBlankNames
        groupOptions = ((try? repo.allGroups()) ?? []).excludingBlankNames
        memberOptions = ((try? repo.allMembers()) ?? []).excludingBlankNames
    }

    /// 近くの過去記録を読み込む
    func loadNearbyVisits(visitId: UUID) async {
        guard let currentVisit = try? repo.get(by: visitId) else { return }

        do {
            let nearby = try repo.fetchNearby(
                latitude: currentVisit.visit.latitude,
                longitude: currentVisit.visit.longitude,
                radius: 100.0,
                excludingId: visitId,
                limit: nil  // 制限なし、すべて表示
            )
            // 日付順、降順でソート
            nearbyVisits = nearby.sorted { $0.visit.timestampUTC > $1.visit.timestampUTC }
            nearbyVisitsData = nearbyVisits.map { VisitDetailDataBuilder.toDetailData($0, labelOptions: labelOptions, groupOptions: groupOptions, memberOptions: memberOptions) }
        } catch {
            Logger.error("Failed to fetch nearby visits", error: error)
        }
    }

    /// 同じグループの記録を読み込む
    func loadSameGroupVisits(visitId: UUID) async {
        guard let currentVisit = try? repo.get(by: visitId) else { return }
        guard let groupId = currentVisit.details.groupId else { return }

        // グループ名を取得
        currentGroupName = groupOptions.first(where: { $0.id == groupId })?.name

        do {
            let visits = try repo.fetchAll(
                filterLabel: nil,
                filterGroup: groupId,
                filterMember: nil,
                titleQuery: nil,
                dateFrom: nil,
                dateToExclusive: nil
            )

            // 現在の記録を除外し、日付順（降順）でソート
            sameGroupVisits = visits
                .filter { $0.visit.id != visitId }
                .sorted { $0.visit.timestampUTC > $1.visit.timestampUTC }

            sameGroupVisitsData = sameGroupVisits.map { VisitDetailDataBuilder.toDetailData($0, labelOptions: labelOptions, groupOptions: groupOptions, memberOptions: memberOptions) }
        } catch {
            Logger.error("Failed to fetch same group visits", error: error)
        }
    }

    /// この記録に紐づくコース到達の順位（「◯人目」）を読み込む。
    /// サーバーへの送信がまだ完了していない（rankが未確定）場合は表示しない
    func loadCourseArrivalInfo(visitId: UUID) async {
        guard let arrivals = try? spotArrivalOutboxRepo.fetchByVisitId(visitId) else { return }

        var results: [CourseArrivalRankInfo] = []
        for arrival in arrivals {
            guard let rank = arrival.rank else { continue }
            guard let course = try? courseRepo.fetch(id: arrival.courseId) else { continue }
            guard let spot = course.spots.first(where: { $0.id == arrival.spotId }) else { continue }
            results.append(CourseArrivalRankInfo(id: spot.id, course: course, spot: spot, rank: rank))
        }
        courseArrivalInfo = results
    }

    // MARK: - タクソノミー選択ハンドラ

    /// ラベルタップ時の処理
    func handleLabelTap(_ labelName: String) {
        if let label = labelOptions.first(where: { $0.name == labelName }) {
            selectedLabel = label
        }
    }

    /// グループタップ時の処理
    func handleGroupTap(_ groupName: String) {
        if let group = groupOptions.first(where: { $0.name == groupName }) {
            selectedGroup = group
        }
    }

    /// メンバータップ時の処理
    func handleMemberTap(_ memberName: String) {
        if let member = memberOptions.first(where: { $0.name == memberName }) {
            selectedMember = member
        }
    }

}

/// この記録で到達したコーススポットの「◯人目」表示用データ
struct CourseArrivalRankInfo: Identifiable {
    let id: UUID
    let course: Course
    let spot: CourseSpot
    let rank: Int
}
