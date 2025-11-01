import Foundation
import CoreLocation
import Contacts
import UIKit
import Observation

@MainActor
@Observable
final class CreateEditStore {

    // MARK: - Inputs (表示・編集用)
    var timestampDisplay: Date = Date()
    var latitude: Double = 0
    var longitude: Double = 0
    var accuracy: Double?
    var addressLine: String? = nil

    var title: String = ""
    var facilityName: String? = nil
    var facilityAddress: String? = nil
    var facilityCategory: String? = nil
    var comment: String = ""
    var labelIds: Set<UUID> = []
    var groupId: UUID?
    var memberIds: Set<UUID> = []

    // MARK: - UI State
    var alert: String?
    var showActionPrompt: Bool = false
    var shouldDismiss: Bool = false  // 権限拒否時に画面を閉じる

    // 測位フラグ（偽装/外部アクセサリ検知）
    private var lastFlags = LocationSourceFlags(
        isSimulatedBySoftware: nil,
        isProducedByAccessory: nil
    )

    // MARK: - Dependencies (Services)
    private let integ: IntegrityService
    private let repo: VisitRepository & TaxonomyRepository

    /// 写真管理サービス
    let photoService: PhotoEditService

    /// 位置情報・住所逆引きサービス
    private let locationGeocodingService: LocationGeocodingService

    /// POI検索・調整サービス
    let poiCoordinator: POICoordinatorService

    // MARK: - Dependencies (Logic)

    /// 位置情報検証ロジック（純粋関数）
    private let locationValidator = LocationValidator()

    // MARK: - Initialization

    init(
        loc: LocationService,
        poi: PlaceLookupService,
        integ: IntegrityService,
        repo: VisitRepository & TaxonomyRepository,
        initialLocationData: LocationData? = nil
    ) {
        self.integ = integ
        self.repo = repo

        // サービスを初期化
        self.photoService = PhotoEditService()
        self.locationGeocodingService = LocationGeocodingService(locationService: loc)
        self.poiCoordinator = POICoordinatorService(poiService: poi)

        // 初期位置情報がある場合は設定
        if let data = initialLocationData {
            self.timestampDisplay = data.timestamp
            self.latitude = data.latitude
            self.longitude = data.longitude
            self.accuracy = data.accuracy
            self.addressLine = data.address
            self.lastFlags = data.flags
        }
    }

    // 初期化後にPOIを開く（Viewから呼ばれる）
    func openPOIIfNeeded(shouldOpenPOI: Bool) {
        if shouldOpenPOI {
            Task { @MainActor in
                await openPOI()
            }
        }
    }

    // MARK: - Computed Properties (POI)

    /// POIシートを表示すべきかどうか（データが揃っている場合のみtrue）
    var shouldShowPOISheet: Bool {
        poiCoordinator.showPOI && !poiCoordinator.poiList.isEmpty
    }

    /// POIシートを閉じる（View側から呼ばれる）
    func closePOISheet() {
        poiCoordinator.closePOI()
    }

    // MARK: - Load Existing

    func loadExisting(_ agg: VisitAggregate) {
        timestampDisplay = agg.visit.timestampUTC
        latitude  = agg.visit.latitude
        longitude = agg.visit.longitude
        accuracy  = agg.visit.horizontalAccuracy
        title     = agg.details.title ?? ""
        facilityName = agg.details.facilityName ?? ""
        facilityAddress = agg.details.facilityAddress ?? ""
        facilityCategory = agg.details.facilityCategory
        comment   = agg.details.comment ?? ""
        labelIds = Set(agg.details.labelIds)
        groupId   = agg.details.groupId
        memberIds = Set(agg.details.memberIds)
        addressLine = agg.details.resolvedAddress

        // 写真はサービス経由で管理
        photoService.loadForEdit(agg.details.photoPaths)
    }

    // MARK: - UI Actions

    @MainActor
    @MainActor
    func presentPostKokokitaPromptIfReady() {
        // 座標検証（純粋関数）
        if locationValidator.isValidCoordinate(latitude: latitude, longitude: longitude) {
            showActionPrompt = true
        }
    }

    @MainActor
    func clearFacilityInfo() {
        self.facilityName = nil
        self.facilityAddress = nil
        self.facilityCategory = nil
    }

    // MARK: - Location

    func requestLocation() async {
        do {
            let result = try await locationGeocodingService.requestLocationWithAddress { [weak self] address in
                // バックグラウンドで住所が取得できた時の処理
                guard let self = self else { return }
                self.addressLine = address
            }

            lastFlags = result.flags
            timestampDisplay = result.timestamp
            latitude = result.latitude
            longitude = result.longitude
            accuracy = result.accuracy
            addressLine = result.address

        } catch let error as LocationServiceError {
            switch error {
            case .permissionDenied:
                // 権限が拒否された場合は画面を閉じる
                shouldDismiss = true
            case .other:
                alert = error.localizedDescription
            }
        } catch {
            alert = error.localizedDescription
        }
    }

    // MARK: - POI (ココカモ)

    func openPOI() async {
        do {
            try await poiCoordinator.searchAndShowPOI(latitude: latitude, longitude: longitude)
        } catch {
            alert = error.localizedDescription
        }
    }

    func applyPOI(_ poi: PlacePOI) {
        let data = poiCoordinator.getApplicableData(from: poi)
        self.title = data.title
        self.facilityName = data.facilityName
        self.facilityAddress = data.facilityAddress
        self.facilityCategory = data.facilityCategory
        poiCoordinator.closePOI()
    }

    // MARK: - Create / Update

    @discardableResult
    @discardableResult
    func createNew() -> Bool {
        do {
            // 位置情報検証（純粋関数）
            if locationValidator.isSimulated(lastFlags) {
                alert = L.Error.locationSimulated
                return false
            }

            let id  = UUID()
            let utc = Date() // 保存はUTC

            let integrity = try integ.signImmutablePayload(
                id: id,
                timestampUTC: utc,
                lat: latitude,
                lon: longitude,
                acc: accuracy,
                flags: lastFlags
            )

            let visit = Visit(
                id: id,
                timestampUTC: utc,
                latitude: latitude,
                longitude: longitude,
                horizontalAccuracy: accuracy,
                isSimulatedBySoftware: lastFlags.isSimulatedBySoftware,
                isProducedByAccessory: lastFlags.isProducedByAccessory,
                integrity: integrity
            )

            let details = VisitDetails(
                title: title.nilIfBlank,
                facilityName: facilityName,
                facilityAddress: facilityAddress,
                facilityCategory: facilityCategory,
                comment: comment.nilIfBlank,
                labelIds: Array(labelIds),
                groupId: groupId,
                memberIds: Array(memberIds),
                resolvedAddress: addressLine,
                photoPaths: photoService.getCurrentPaths()
            )

            try repo.create(visit: visit, details: details)
            return true
        } catch {
            alert = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func saveEdits(for id: UUID) -> Bool {
        do {
            try repo.updateDetails(id: id) { cur in
                cur.title = title.isEmpty ? nil : title
                cur.facilityName = facilityName
                cur.facilityAddress = facilityAddress
                cur.facilityCategory = facilityCategory
                cur.comment = comment.isEmpty ? nil : comment
                cur.labelIds = Array(labelIds)
                cur.groupId = groupId
                cur.memberIds = Array(memberIds)
                if let addr = addressLine, !addr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    cur.resolvedAddress = addr
                }
                // 写真はサービスから取得
                cur.photoPaths = photoService.getCurrentPaths()
            }

            // 写真編集を確定
            photoService.commitEdits()

            return true
        } catch {
            alert = error.localizedDescription
            return false
        }
    }

    // MARK: - Taxonomy helpers

    func createLabel(_ name: String) -> UUID? {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return nil }

        do {
            // 既存と重複していればそれを返す（任意）
            if let exist = try? repo.allLabels().first(where: { $0.name == n }) {
                return exist.id
            }
            let id = try repo.createLabel(name: n)
            NotificationCenter.default.post(name: .taxonomyChanged, object: nil)
            return id
        } catch {
            self.alert = error.localizedDescription
            return nil
        }
    }

    func createGroup(_ name: String) -> UUID? {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return nil }

        do {
            if let exist = try? repo.allGroups().first(where: { $0.name == n }) {
                return exist.id
            }
            let id = try repo.createGroup(name: n)
            NotificationCenter.default.post(name: .taxonomyChanged, object: nil)
            return id
        } catch {
            self.alert = error.localizedDescription
            return nil
        }
    }

    func createMember(_ name: String) -> UUID? {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return nil }

        do {
            if let exist = try? repo.allMembers().first(where: { $0.name == n }) {
                return exist.id
            }
            let id = try repo.createMember(name: n)
            NotificationCenter.default.post(name: .taxonomyChanged, object: nil)
            return id
        } catch {
            self.alert = error.localizedDescription
            return nil
        }
    }

    // MARK: - Photo Delegation (便利メソッド)

    func addPhotos(_ images: [UIImage]) {
        photoService.addPhotos(images)
    }

    func removePhoto(at index: Int) {
        photoService.removePhoto(at: index)
    }

    func discardPhotoEditingIfNeeded() {
        photoService.discardEditingIfNeeded()
    }
}

// MARK: - Helpers
private extension String {
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
