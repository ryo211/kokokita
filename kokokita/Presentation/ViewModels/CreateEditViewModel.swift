import Foundation
import CoreLocation
import Contacts
import UIKit
import Combine

@MainActor
final class CreateEditViewModel: ObservableObject {

    // MARK: - Inputs (表示・編集用)
    @Published var timestampDisplay: Date = Date()
    @Published var latitude: Double = 0
    @Published var longitude: Double = 0
    @Published var accuracy: Double?
    @Published var addressLine: String? = nil

    @Published var title: String = ""
    @Published var facilityName: String? = nil
    @Published var facilityAddress: String? = nil
    @Published var comment: String = ""
    @Published var labelIds: Set<UUID> = []
    @Published var groupId: UUID?

    // MARK: - UI State
    @Published var alert: String?
    @Published var showActionPrompt: Bool = false
    @Published var shouldDismiss: Bool = false  // 権限拒否時に画面を閉じる

    // POI関連のUI状態（ViewからBindingするため@Publishedで公開）
    @Published var showPOI: Bool = false {
        didSet {
            // ViewからshowPOIが変更されたらpoiCoordinatorにも反映
            if showPOI != poiCoordinator.showPOI {
                poiCoordinator.showPOI = showPOI
            }
        }
    }
    @Published var poiList: [PlacePOI] = []

    // 測位フラグ（偽装/外部アクセサリ検知）
    private var lastFlags = LocationSourceFlags(
        isSimulatedBySoftware: nil,
        isProducedByAccessory: nil
    )

    // MARK: - Dependencies (Services)
    private let integ: IntegrityService
    private let repo: VisitRepository & TaxonomyRepository
    private var cancellables = Set<AnyCancellable>()

    /// 写真管理サービス
    let photoService: PhotoEditService

    /// 位置情報・住所逆引きサービス
    private let locationGeocodingService: LocationGeocodingService

    /// POI検索・調整サービス
    private let poiCoordinator: POICoordinatorService

    // MARK: - Initialization

    init(
        loc: LocationService,
        poi: PlaceLookupService,
        integ: IntegrityService,
        repo: VisitRepository & TaxonomyRepository
    ) {
        self.integ = integ
        self.repo = repo

        // サービスを初期化
        self.photoService = PhotoEditService()
        self.locationGeocodingService = LocationGeocodingService(locationService: loc)
        self.poiCoordinator = POICoordinatorService(poiService: poi)

        // POI状態の同期（poiCoordinatorの変更をViewModelに反映）
        setupPOIBinding()

        // PhotoService の変更をViewModelに伝播
        setupPhotoBinding()
    }

    private func setupPOIBinding() {
        // poiCoordinatorのshowPOIとpoiListの変更を監視してViewModelに反映
        poiCoordinator.$showPOI
            .assign(to: &$showPOI)
        poiCoordinator.$poiList
            .assign(to: &$poiList)
    }

    private func setupPhotoBinding() {
        // photoServiceの変更をこのViewModelの変更として伝播
        photoService.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
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
        comment   = agg.details.comment ?? ""
        labelIds = Set(agg.details.labelIds)
        groupId   = agg.details.groupId
        addressLine = agg.details.resolvedAddress

        // 写真はサービス経由で管理
        photoService.loadForEdit(agg.details.photoPaths)
    }

    // MARK: - UI Actions

    @MainActor
    func presentPostKokokitaPromptIfReady() {
        // 緯度経度が入っていれば出す（0,0 のときは出さない）
        if latitude != 0 || longitude != 0 {
            showActionPrompt = true
        }
    }

    @MainActor
    func clearFacilityInfo() {
        self.facilityName = nil
        self.facilityAddress = nil
    }

    // MARK: - Location

    func requestLocation() async {
        do {
            let result = try await locationGeocodingService.requestLocationWithAddress()

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
        poiCoordinator.closePOI()
    }

    // MARK: - Create / Update

    @discardableResult
    func createNew() -> Bool {
        do {
            if lastFlags.isSimulatedBySoftware == true || lastFlags.isProducedByAccessory == true {
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
                comment: comment.nilIfBlank,
                labelIds: Array(labelIds),
                groupId: groupId,
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
                cur.comment = comment.isEmpty ? nil : comment
                cur.labelIds = Array(labelIds)
                cur.groupId = groupId
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
