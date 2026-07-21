import Foundation
import CoreLocation

/// CLVisit 監視を通じて訪問候補を自動収集するサービス
/// バックグラウンドでも動作し、足切り条件を満たした Visit を VisitCandidateRepository に保存する
final class AutoRecordService: NSObject {
    private let manager = CLLocationManager()
    private let candidateRepo: VisitCandidateRepository
    private let excludedRepo: ExcludedLocationRepository
    private let settings: AutoRecordSettings

    init(
        candidateRepo: VisitCandidateRepository = VisitCandidateRepository(),
        excludedRepo: ExcludedLocationRepository = ExcludedLocationRepository(),
        settings: AutoRecordSettings = .shared
    ) {
        self.candidateRepo = candidateRepo
        self.excludedRepo = excludedRepo
        self.settings = settings
        super.init()
        manager.delegate = self
    }

    // MARK: - 監視開始・停止

    func startMonitoring() {
        guard settings.isEnabled else {
            Logger.info("自動記録は無効化されています")
            return
        }
        manager.startMonitoringVisits()
        Logger.info("自動記録: CLVisit 監視を開始しました")
    }

    func stopMonitoring() {
        manager.stopMonitoringVisits()
        Logger.info("自動記録: CLVisit 監視を停止しました")
    }

    // MARK: - Always 権限要求

    /// 自動記録を有効化する際に Always 権限を要求する
    func requestAlwaysAuthorization() {
        let status = manager.authorizationStatus
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    // MARK: - 古い候補の削除

    /// 保持期間を超えた候補を削除する（起動時に呼ぶ）
    func cleanUpOldCandidates() {
        let cutoff = Date().addingTimeInterval(-(AppConfig.autoRecordRetentionDays * 86400.0))
        do {
            try candidateRepo.dismissOlderThan(date: cutoff)
            AppIconBadgeService.shared.syncAutoRecordCandidateCount(candidateRepo: candidateRepo)
        } catch {
            Logger.error("古い自動記録候補の削除に失敗しました", error: error)
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension AutoRecordService: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        Logger.info("CLVisit 受信: lat=\(visit.coordinate.latitude), acc=\(visit.horizontalAccuracy)m, arrival=\(visit.arrivalDate)")

        // departureDate 未確定は保留（CLVisit は未出発時に Date.distantFuture を設定する）
        guard visit.departureDate < Date.distantFuture else {
            Logger.debug("自動記録: departureDate 未確定のため保留")
            return
        }

        // 精度足切り
        guard visit.horizontalAccuracy <= AppConfig.autoRecordMaxAccuracyMeters else {
            Logger.debug("自動記録: 精度不足で破棄 (\(visit.horizontalAccuracy)m > \(AppConfig.autoRecordMaxAccuracyMeters)m)")
            return
        }

        // 滞在時間足切り（短すぎる・長すぎる滞在を除外）
        let stayDuration = visit.departureDate.timeIntervalSince(visit.arrivalDate)
        guard stayDuration >= AppConfig.autoRecordMinStaySeconds else {
            Logger.debug("自動記録: 滞在時間不足で破棄 (\(Int(stayDuration))秒 < \(Int(AppConfig.autoRecordMinStaySeconds))秒)")
            return
        }
        guard stayDuration <= AppConfig.autoRecordMaxStaySeconds else {
            Logger.debug("自動記録: 滞在時間超過で破棄 (\(Int(stayDuration / 3600))時間 > 72時間)")
            return
        }

        // 除外エリアチェック
        do {
            if try excludedRepo.isExcluded(latitude: visit.coordinate.latitude, longitude: visit.coordinate.longitude) {
                Logger.debug("自動記録: 除外エリア内のため破棄 (lat=\(visit.coordinate.latitude), lon=\(visit.coordinate.longitude))")
                return
            }
        } catch {
            Logger.error("除外エリアチェックに失敗しました", error: error)
        }

        // 上限件数チェック
        do {
            let count = try candidateRepo.countPending()
            if count >= AppConfig.autoRecordMaxCandidates {
                Logger.warning("自動記録: 候補上限 (\(AppConfig.autoRecordMaxCandidates)件) に達したため破棄")
                return
            }
        } catch {
            Logger.error("自動記録候補数の取得に失敗しました", error: error)
        }

        // 候補として保存
        let candidate = VisitCandidate(
            id: UUID(),
            latitude: visit.coordinate.latitude,
            longitude: visit.coordinate.longitude,
            arrivalDate: visit.arrivalDate,
            departureDate: visit.departureDate,
            horizontalAccuracy: visit.horizontalAccuracy,
            placeName: nil,
            status: .pending,
            detectedAt: Date()
        )

        do {
            try candidateRepo.save(candidate)
            AppIconBadgeService.shared.syncAutoRecordCandidateCount(candidateRepo: candidateRepo)
            Logger.success("自動記録候補を保存しました (滞在:\(Int(stayDuration / 60))分)")
        } catch {
            Logger.error("自動記録候補の保存に失敗しました", error: error)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Logger.info("自動記録: 権限ステータス変更 -> \(status.rawValue)")

        // Always 権限が付与されたら監視を開始
        if status == .authorizedAlways && settings.isEnabled {
            manager.startMonitoringVisits()
            Logger.info("自動記録: Always 権限取得, CLVisit 監視を開始")
        }
    }
}
