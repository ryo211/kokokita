import Foundation
import CoreLocation
import Observation

/// 自動記録候補レビュー画面の状態管理
@MainActor
@Observable
final class AutoRecordCandidateStore {
    private let candidateRepo: VisitCandidateRepository
    private let visitRepo: CoreDataVisitRepository
    private let geocoder = CLGeocoder()

    var candidates: [VisitCandidate] = []
    var isLoading = false
    var approvedVisitId: UUID?
    var errorMessage: String?

    init(
        candidateRepo: VisitCandidateRepository = AppContainer.shared.candidateRepo,
        visitRepo: CoreDataVisitRepository = AppContainer.shared.repo
    ) {
        self.candidateRepo = candidateRepo
        self.visitRepo = visitRepo
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

    /// 候補を承認して後付け記録として確定する
    /// - Returns: 新しく作成された Visit の ID（編集画面への遷移用）
    @discardableResult
    func approve(candidate: VisitCandidate) throws -> UUID {
        let visitId = UUID()
        let visit = Visit(
            id: visitId,
            timestampUTC: candidate.arrivalDate,
            latitude: candidate.latitude,
            longitude: candidate.longitude,
            horizontalAccuracy: candidate.horizontalAccuracy
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
        try visitRepo.createManualEntry(visit: visit, details: details)
        try candidateRepo.deleteAfterApproval(id: candidate.id)
        candidates.removeAll { $0.id == candidate.id }
        NotificationCenter.default.post(name: .visitsChanged, object: nil)
        Logger.success("自動記録を承認・確定しました: \(visitId)")
        approvedVisitId = visitId
        return visitId
    }

    // MARK: - 却下

    func dismiss(candidate: VisitCandidate) throws {
        try candidateRepo.dismiss(id: candidate.id)
        candidates.removeAll { $0.id == candidate.id }
        Logger.info("候補を却下しました: \(candidate.id)")
    }

    func dismissAll() throws {
        for candidate in candidates {
            try candidateRepo.dismiss(id: candidate.id)
        }
        candidates.removeAll()
        Logger.info("全候補を却下しました")
    }

    var pendingCount: Int { candidates.count }
}
