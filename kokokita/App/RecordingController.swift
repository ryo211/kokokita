import SwiftUI
import CoreLocation

// 記録機能の状態・ロジックを管理するコントローラー
// RootTabView と PilgrimageRootTabView で共有して使用
@MainActor
@Observable
final class RecordingController {

    // MARK: - 状態

    var showLocationLoading = false
    var showLocationPermissionAlert = false
    var confirmationSheetVisitId: UUID?
    var pendingCheckInResults: [CourseRecognitionService.RecognitionResult] = []
    var pendingConfirmationId: UUID?
    var editVisitId: UUID?
    var detailVisitId: UUID?
    var locationErrorMessage: String?
    var showManualEntrySheet = false

    // MARK: - 記録起動

    func checkLocationPermissionAndCreate() {
        let locationManager = CLLocationManager()
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse, .notDetermined:
            Task { await fetchLocationAndShowPrompt() }
        case .denied, .restricted:
            showLocationPermissionAlert = true
        @unknown default:
            Task { await fetchLocationAndShowPrompt() }
        }
    }

    // MARK: - 位置情報取得

    @MainActor
    func fetchLocationAndShowPrompt() async {
        showLocationLoading = true

        do {
            let locationService = LocationGeocodingService(
                locationService: AppContainer.shared.loc
            )

            // 低精度で素早く取得
            let quickResult = try await locationService.requestQuickLocation { _ in }
            let quickData = LocationData(
                timestamp: quickResult.timestamp,
                latitude: quickResult.latitude,
                longitude: quickResult.longitude,
                accuracy: quickResult.accuracy,
                address: quickResult.address,
                flags: quickResult.flags
            )

            guard let savedId = quickSaveLocation(quickData) else {
                showLocationLoading = false
                locationErrorMessage = L.Error.saveFailed
                return
            }

            showLocationLoading = false

            // コース認識（visitId を渡してスポットと訪問記録を紐づける）
            let checkInResults = runCourseRecognition(
                latitude: quickData.latitude,
                longitude: quickData.longitude,
                visitId: savedId
            )

            if !checkInResults.isEmpty {
                pendingCheckInResults = checkInResults
                pendingConfirmationId = savedId
            } else {
                confirmationSheetVisitId = savedId
            }

            // バックグラウンドで高精度取得して更新
            Task {
                await refineLocationAndUpdate(
                    savedId: savedId,
                    locationService: locationService,
                    quickData: quickData
                )
            }

        } catch {
            showLocationLoading = false

            if case LocationServiceError.permissionDenied = error {
                showLocationPermissionAlert = true
            } else {
                Logger.error("位置情報取得失敗", error: error)
                locationErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    // MARK: - 高精度更新

    @MainActor
    func refineLocationAndUpdate(
        savedId: UUID,
        locationService: LocationGeocodingService,
        quickData: LocationData
    ) async {
        do {
            let refinedResult = try await locationService.refineLocation { _ in }
            let repo = AppContainer.shared.repo
            try repo.updateDetails(id: savedId) { details in
                details.resolvedAddress = refinedResult.address ?? quickData.address
            }

            #if DEBUG
            let integ = AppContainer.shared.integ
            let newIntegrity = try integ.signImmutablePayload(
                id: savedId,
                timestampUTC: quickData.timestamp,
                lat: refinedResult.latitude,
                lon: refinedResult.longitude,
                acc: refinedResult.accuracy,
                flags: refinedResult.flags,
                createdAtUTC: quickData.timestamp
            )
            try repo.updateVisitTimestamp(
                id: savedId,
                newTimestamp: quickData.timestamp,
                newIntegrity: newIntegrity
            )
            #endif

            Logger.info("Location refined to higher accuracy: \(refinedResult.accuracy ?? 0)m")
            NotificationCenter.default.post(name: .visitsChanged, object: nil)
        } catch {
            Logger.warning("Failed to refine location, using quick result: \(error.localizedDescription)")
        }
    }

    // MARK: - 保存

    @discardableResult
    func quickSaveLocation(_ data: LocationData) -> UUID? {
        let repo = AppContainer.shared.repo
        let integ = AppContainer.shared.integ

        do {
            let id = UUID()
            let integrity = try integ.signImmutablePayload(
                id: id,
                timestampUTC: data.timestamp,
                lat: data.latitude,
                lon: data.longitude,
                acc: data.accuracy,
                flags: data.flags
            )
            let visit = Visit(
                id: id,
                timestampUTC: data.timestamp,
                latitude: data.latitude,
                longitude: data.longitude,
                horizontalAccuracy: data.accuracy,
                isSimulatedBySoftware: data.flags.isSimulatedBySoftware,
                isProducedByAccessory: data.flags.isProducedByAccessory,
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
                resolvedAddress: data.address,
                photoPaths: []
            )
            try repo.create(visit: visit, details: details)
            NotificationCenter.default.post(name: .visitsChanged, object: nil)
            AppReviewService.shared.recordCreated()
            return id
        } catch {
            Logger.error("Quick save failed", error: error)
            return nil
        }
    }

    // MARK: - コース認識

    @MainActor
    func runCourseRecognition(latitude: Double, longitude: Double, visitId: UUID? = nil) -> [CourseRecognitionService.RecognitionResult] {
        let svc = AppContainer.shared.courseRecognitionService
        let courseRepo = AppContainer.shared.courseRepo
        do {
            let results = try svc.recognize(latitude: latitude, longitude: longitude, isManualEntry: false)
            guard !results.isEmpty else { return [] }

            let checkInTime = Date()
            let checkedSpotIds = Set(results.map { $0.spot.id })

            for result in results {
                try courseRepo.checkIn(spotId: result.spot.id, visitId: visitId)
            }
            NotificationCenter.default.post(name: .courseChanged, object: nil)

            return results.map { result in
                // セクション構造を保持しつつチェックイン済みスポットのみ visitIds を更新
                let updatedSections = result.course.sections.map { section in
                    CourseSection(
                        id: section.id, sectionId: section.sectionId,
                        name: section.name, sectionDescription: section.sectionDescription,
                        orderIndex: section.orderIndex, coverImageUrl: section.coverImageUrl,
                        spots: section.spots.map { spot -> CourseSpot in
                            guard checkedSpotIds.contains(spot.id) else { return spot }
                            // visitIds は UI 上の一時オブジェクトなので既存 + 今回の visitId を反映
                            let newVisitIds: [UUID]
                            if let vid = visitId {
                                newVisitIds = spot.visitIds + [vid]
                            } else {
                                newVisitIds = spot.visitIds
                            }
                            return CourseSpot(
                                id: spot.id, spotId: spot.spotId, name: spot.name,
                                address: spot.address, latitude: spot.latitude,
                                longitude: spot.longitude, spotDescription: spot.spotDescription,
                                coverImageUrl: spot.coverImageUrl,
                                localCoverImagePath: spot.localCoverImagePath,
                                orderIndex: spot.orderIndex,
                                recognitionRadiusMeters: spot.recognitionRadiusMeters,
                                firstCheckedInAt: checkInTime,
                                visitIds: newVisitIds
                            )
                        }
                    )
                }
                let updatedCourse = Course(
                    id: result.course.id, courseType: result.course.courseType,
                    title: result.course.title, summary: result.course.summary,
                    source: result.course.source, isUserCreated: result.course.isUserCreated,
                    version: result.course.version,
                    recognitionRadiusMeters: result.course.recognitionRadiusMeters,
                    everEnabled: result.course.everEnabled,
                    isEnabled: result.course.isEnabled,
                    allowRetroactive: result.course.allowRetroactive,
                    detailUrl: result.course.detailUrl,
                    coverImageUrl: result.course.coverImageUrl,
                    localCoverImagePath: result.course.localCoverImagePath,
                    createdAt: result.course.createdAt, updatedAt: result.course.updatedAt,
                    categories: result.course.categories,
                    sections: updatedSections
                )
                let updatedSpots = updatedSections.flatMap(\.spots)
                let updatedSpot = updatedSpots.first(where: { $0.id == result.spot.id }) ?? result.spot
                return CourseRecognitionService.RecognitionResult(
                    course: updatedCourse, spot: updatedSpot,
                    distanceMeters: result.distanceMeters, achievedAt: result.achievedAt
                )
            }
        } catch {
            Logger.error("コース認識エラー", error: error)
            return []
        }
    }

    // MARK: - その他

    func deleteVisit(id: UUID) {
        do {
            try AppContainer.shared.repo.delete(id: id)
            NotificationCenter.default.post(name: .visitsChanged, object: nil)
        } catch {
            Logger.error("Failed to delete visit", error: error)
            locationErrorMessage = L.Error.deleteFailed
        }
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
