import Foundation
import Observation
import SwiftUI
import MapKit
import CoreLocation

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

    // MARK: - 共有
    var sharePayload: SharePayload? = nil

    // MARK: - 削除確認
    var showDeleteAlert = false

    // MARK: - タクソノミー選択（詳細画面遷移用）
    var selectedLabel: LabelTag? = nil
    var selectedGroup: GroupTag? = nil
    var selectedMember: MemberTag? = nil

    /// ラベル名 -> 色のマップ（labelOptions から構築）
    var labelColorMap: [String: Color] { labelOptions.colorMap }

    // MARK: - 依存
    private let repo: CoreDataVisitRepository

    init(repo: CoreDataVisitRepository = AppContainer.shared.repo) {
        self.repo = repo
    }

    // MARK: - データロード

    /// タクソノミー（ラベル・グループ・メンバー）を読み込む
    func loadTaxonomyData() async {
        labelOptions = ((try? repo.allLabels()) ?? []).sortedByName
        groupOptions = ((try? repo.allGroups()) ?? []).sortedByName
        memberOptions = ((try? repo.allMembers()) ?? []).sortedByName
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

    // MARK: - 共有

    /// SNSカード画像を生成して共有シートを表示する
    func makeAndShare(data: VisitDetailData) async {
        // 1) 地図スナップショット（オフスクリーンでも確実に出る）
        var mapImage: UIImage? = nil
        if let c = data.coordinate {
            mapImage = await MapSnapshotService.makeSnapshot(
                center: c,
                size: CGSize(width: AppConfig.shareImageLogicalWidth, height: UIConstants.Size.shareMapHeight),
                spanMeters: AppConfig.mapDisplayRadius,
                showCoordinateBadge: true,
                decimals: AppConfig.coordinateDecimals,
                badgeInset: UIConstants.Spacing.medium
            )
        }

        // 2) 同じ中身を共有用フラグでレンダリング
        let currentLabelColorMap = labelColorMap
        let img: UIImage? = await MainActor.run {
            let content = VStack(spacing: 0) {
                VisitDetailContent(
                    data: data,
                    mapSnapshot: mapImage,
                    isSharing: true,
                    nearbyVisits: [],  // 共有時は近くの記録は含めない
                    nearbyVisitsData: [],
                    sameGroupVisits: [],  // 共有時はグループ記録は含めない
                    sameGroupVisitsData: [],
                    currentGroupName: nil,
                    labelColorMap: currentLabelColorMap,
                    photoFullScreenIndex: .constant(nil)
                )
                .padding(.all, UIConstants.Spacing.xxLarge)
            }
            return ShareImageRenderer.renderWidth(content, width: AppConfig.shareImageLogicalWidth, scale: AppConfig.shareImageScale)
        }

        // 3) シート表示
        if let img {
            self.sharePayload = SharePayload(image: img, text: VisitDetailDataBuilder.shareText(data: data))
        }
    }
}
