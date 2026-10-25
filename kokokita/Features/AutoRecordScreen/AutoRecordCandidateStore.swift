import Foundation
import CoreLocation
import Observation

/// 自動記録候補レビュー画面の状態管理
@MainActor
@Observable
final class AutoRecordCandidateStore {
    private let candidateRepo: VisitCandidateRepository
    private let visitRepo: CoreDataVisitRepository
    private let excludedRepo: ExcludedLocationRepository
    private let courseRecognitionService: CourseRecognitionService?
    private let courseRepo: CourseRepository?
    private let geocoder = CLGeocoder()

    var candidates: [VisitCandidate] = []
    var isLoading = false
    var approvedVisitId: UUID?
    var errorMessage: String?
    /// 承認した候補がコーススポットの認識条件を満たした場合の判定結果
    /// （ここキタボタン押下時と同じ達成シートを表示するために使用）
    var pendingCheckInResults: [CourseRecognitionService.RecognitionResult] = []

    init(
        candidateRepo: VisitCandidateRepository = AppContainer.shared.candidateRepo,
        visitRepo: CoreDataVisitRepository = AppContainer.shared.repo,
        excludedRepo: ExcludedLocationRepository = AppContainer.shared.excludedLocationRepo,
        courseRecognitionService: CourseRecognitionService? = AppContainer.shared.courseRecognitionService,
        courseRepo: CourseRepository? = AppContainer.shared.courseRepo
    ) {
        self.candidateRepo = candidateRepo
        self.visitRepo = visitRepo
        self.excludedRepo = excludedRepo
        self.courseRecognitionService = courseRecognitionService
        self.courseRepo = courseRepo
    }

    // MARK: - 読み込み

    func load() async {
        isLoading = true
        do {
            candidates = try candidateRepo.fetchPending()
            await resolveGeocodings()
        } catch {
            errorMessage = error.localizedDescription
            Logger.error("候補の読み込みに失敗しました", error: error)
        }
        isLoading = false
    }

    /// 地名未取得の候補に対して逆ジオコーディングを実行する
    private func resolveGeocodings() async {
        for (index, candidate) in candidates.enumerated() where candidate.placeName == nil {
            let location = CLLocation(latitude: candidate.latitude, longitude: candidate.longitude)
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                if let pm = placemarks.first {
                    let name = formatPlaceName(from: pm)
                    candidates[index] = VisitCandidate(
                        id: candidate.id,
                        latitude: candidate.latitude,
                        longitude: candidate.longitude,
                        arrivalDate: candidate.arrivalDate,
                        departureDate: candidate.departureDate,
                        horizontalAccuracy: candidate.horizontalAccuracy,
                        placeName: name,
                        status: candidate.status,
                        detectedAt: candidate.detectedAt
                    )
                    try? candidateRepo.updatePlaceName(id: candidate.id, placeName: name)
                }
            } catch {
                Logger.debug("逆ジオコーディング失敗: \(candidate.id) - \(error.localizedDescription)")
            }
            // CLGeocoder はリクエスト間隔を要求するため少し待機
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    private func formatPlaceName(from pm: CLPlacemark) -> String {
        var parts: [String] = []
        if let admin = pm.administrativeArea { parts.append(admin) }
        if let locality = pm.locality { parts.append(locality) }
        if let subLocality = pm.subLocality { parts.append(subLocality) }
        if let thoroughfare = pm.thoroughfare { parts.append(thoroughfare) }
        return parts.joined()
    }

    // MARK: - 承認

    /// 候補を承認して証明付き記録として確定する（CLVisit由来のGPS座標を署名付きで保存）
    /// - Returns: 新しく作成された Visit の ID（編集画面への遷移用）
    @discardableResult
    func approve(candidate: VisitCandidate) throws -> UUID {
        let visitId = UUID()
        // CLVisit はシステム提供の位置情報のため、ソフトウェアシミュレート・外部アクセサリではない
        let flags = LocationSourceFlags(isSimulatedBySoftware: false, isProducedByAccessory: false)
        let integrity = try AppContainer.shared.integ.signImmutablePayload(
            id: visitId,
            timestampUTC: candidate.arrivalDate,
            lat: candidate.latitude,
            lon: candidate.longitude,
            acc: candidate.horizontalAccuracy,
            flags: flags
        )
        let visit = Visit(
            id: visitId,
            timestampUTC: candidate.arrivalDate,
            latitude: candidate.latitude,
            longitude: candidate.longitude,
            horizontalAccuracy: candidate.horizontalAccuracy,
            isSimulatedBySoftware: false,
            isProducedByAccessory: false,
            integrity: integrity
        )
        let details = VisitDetails(
            title: nil,
            facilityName: nil,
            facilityAddress: nil,
            facilityCategory: nil,
            comment: nil,
            labelIds: [],
            groupId: nil,
            memberIds: [],
            resolvedAddress: candidate.placeName,
            photoPaths: []
        )
        try visitRepo.create(visit: visit, details: details)
        try candidateRepo.deleteAfterApproval(id: candidate.id)
        candidates.removeAll { $0.id == candidate.id }
        AppIconBadgeService.shared.setBadgeCount(candidates.count)
        NotificationCenter.default.post(name: .visitsChanged, object: nil)

        // ここキタボタン押下時（RecordingController.runCourseRecognition）と同様に、保存直後にコース認識を実行する
        pendingCheckInResults = []
        if let svc = courseRecognitionService, let cRepo = courseRepo {
            recognizeCourses(latitude: candidate.latitude, longitude: candidate.longitude, visitId: visitId, service: svc, courseRepo: cRepo)
        }

        Logger.success("自動記録を承認・確定しました: \(visitId)")
        approvedVisitId = visitId
        return visitId
    }

    /// コース認識を実行（RecordingController.runCourseRecognition と同じロジック）
    private func recognizeCourses(
        latitude: Double,
        longitude: Double,
        visitId: UUID,
        service: CourseRecognitionService,
        courseRepo: CourseRepository
    ) {
        do {
            let results = try service.recognize(latitude: latitude, longitude: longitude, isManualEntry: false)
            guard !results.isEmpty else { return }

            for result in results {
                try courseRepo.checkIn(spotId: result.spot.id, visitId: visitId)
            }
            NotificationCenter.default.post(name: .courseChanged, object: nil)

            pendingCheckInResults = results
        } catch {
            Logger.error("コース認識エラー", error: error)
        }
    }

    // MARK: - 却下

    func dismiss(candidate: VisitCandidate) throws {
        try candidateRepo.dismiss(id: candidate.id)
        candidates.removeAll { $0.id == candidate.id }
        AppIconBadgeService.shared.setBadgeCount(candidates.count)
        Logger.info("候補を却下しました: \(candidate.id)")
    }

    func dismissAll() throws {
        for candidate in candidates {
            try candidateRepo.dismiss(id: candidate.id)
        }
        candidates.removeAll()
        AppIconBadgeService.shared.setBadgeCount(0)
        Logger.info("全候補を却下しました")
    }

    // MARK: - 除外エリアへ追加

    /// 候補の場所を除外エリアに登録し、候補自体も却下する
    func excludeAndDismiss(candidate: VisitCandidate, label: String?) throws {
        let location = ExcludedLocation(
            id: UUID(),
            label: label.flatMap { $0.isEmpty ? nil : $0 },
            latitude: candidate.latitude,
            longitude: candidate.longitude,
            radiusMeters: AppConfig.autoRecordExclusionRadiusMeters,
            createdAt: Date()
        )
        try excludedRepo.save(location)
        try candidateRepo.dismiss(id: candidate.id)
        candidates.removeAll { $0.id == candidate.id }
        AppIconBadgeService.shared.setBadgeCount(candidates.count)
        Logger.info("除外エリアに追加し候補を却下しました: \(location.displayLabel)")
    }

    var pendingCount: Int { candidates.count }
}
