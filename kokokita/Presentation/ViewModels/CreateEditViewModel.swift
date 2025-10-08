import Foundation
import CoreLocation
import Contacts
import UIKit

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
    
    @Published var photoPaths: [String] = []
    // --- 写真の編集中ドラフト管理（最小修正） ---
    @Published var photoPathsEditing: [String] = []   // 編集用の一時コピー
    private var originalPhotoPaths: [String] = []     // 編集開始時の元データ
    private var pendingAdds: Set<String> = []         // セッション中に追加された画像
    private var pendingDeletes: Set<String> = []      // 削除予約された既存画像
    @Published var didSave: Bool = false              // 保存済みフラグ
    private var isEditing: Bool = false               // 編集モード中か

    // MARK: - UI State
    @Published var showPOI = false
    @Published var poiList: [PlacePOI] = []
    @Published var alert: String?
    @Published var showActionPrompt: Bool = false
    
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

    private let geocoder = CLGeocoder()
    
    // 測位フラグ（偽装/外部アクセサリ検知）
    private var lastFlags = LocationSourceFlags(            // ← LocationSourceFlags に変更
        isSimulatedBySoftware: nil,
        isProducedByAccessory: nil
    )

    // MARK: - Dependencies
    private let loc: LocationService
    private let poi: PlaceLookupService
    private let integ: IntegrityService
    private let repo: VisitRepository & TaxonomyRepository

    init(
        loc: LocationService,
        poi: PlaceLookupService,
        integ: IntegrityService,
        repo: VisitRepository & TaxonomyRepository
    ) {
        self.loc = loc
        self.poi = poi
        self.integ = integ
        self.repo = repo
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

        // 写真のみドラフト管理
        photoPaths = agg.details.photoPaths
        photoPathsEditing = agg.details.photoPaths
        originalPhotoPaths = agg.details.photoPaths
        pendingAdds.removeAll()
        pendingDeletes.removeAll()
        didSave = false
        isEditing = true
    }


    // MARK: - Location
    func requestLocation() async {
        do {
            let (locResult, flags) = try await loc.requestOneShotLocation() // flags は LocationSourceFlags
            lastFlags = flags

            if flags.isSimulatedBySoftware == true || flags.isProducedByAccessory == true {
                alert = "位置情報がシミュレーション／外部アクセサリ由来の可能性があるため、記録できません。"
                return
            }

            timestampDisplay = Date()
            latitude  = locResult.coordinate.latitude
            longitude = locResult.coordinate.longitude
            accuracy  = locResult.horizontalAccuracy
            
            // 位置を入れた直後あたりに、下を追記
            Task { [weak self] in
                guard let self else { return }
                do {
                    let placemarks = try await self.geocoder.reverseGeocodeLocation(locResult)
                    if let pm = placemarks.first {
                        let addr = Self.formatAddress(pm)
                        await MainActor.run {
                            self.addressLine = addr
                        }
                    }
                } catch {
                    // 失敗時は黙っておく（住所は任意情報）
                    await MainActor.run { self.addressLine = nil }
                }
            }

        } catch {
            alert = error.localizedDescription
        }
    }

    // MARK: - POI (ココカモ)
    func openPOI() async {
        do {
            let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            
            poiList = try await poi.nearbyPOI(center: center, radius: AppConfig.poiSearchRadius) // 戻り値 [PlacePOI]
            showPOI = true
        } catch {
            alert = error.localizedDescription
        }
    }

    func applyPOI(_ poi: PlacePOI) {
        self.title = poi.name
        // ココカモ由来データ
        self.facilityName = poi.name
        self.facilityAddress = poi.address
        self.showPOI = false
    }

    // MARK: - Create / Update
    @discardableResult
    func createNew() -> Bool {
        do {
            if lastFlags.isSimulatedBySoftware == true || lastFlags.isProducedByAccessory == true {
                alert = "位置情報がシミュレーション／外部アクセサリ由来の可能性があるため、記録できません。"
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
                flags: lastFlags                                     // ← LocationSourceFlags
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
                photoPaths: photoPaths
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
                // 写真はドラフトを確定
                cur.photoPaths = photoPathsEditing
            }

            // 削除予約を確定
            for path in pendingDeletes {
                ImageStore.delete(path)
            }

            // 状態を同期
            originalPhotoPaths = photoPathsEditing
            photoPaths = photoPathsEditing
            pendingAdds.removeAll()
            pendingDeletes.removeAll()
            didSave = true
            return true
        } catch {
            alert = error.localizedDescription
            return false
        }
    }


    // MARK: - Taxonomy helpers

    // CreateEditViewModel.swift
    func createLabel(_ name: String) -> UUID? {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return nil }   // UI側でも制御してるけど二重防御

        do {
            // 既存と重複していればそれを返す（任意）
            if let exist = try? repo.allLabels().first(where: { $0.name == n }) {
                return exist.id
            }
            let id = try repo.createLabel(name: n)  // ★ 保存は必ず Repository
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
  
    private static func formatAddress(_ pm: CLPlacemark) -> String {
        if let postal = pm.postalAddress {
            let f = CNPostalAddressFormatter()
            return f.string(from: postal).replacingOccurrences(of: "\n", with: " ")
        }
        return [pm.name, pm.locality, pm.administrativeArea, pm.country]
            .compactMap { $0 }
            .joined(separator: " ")
    }
    
    func addPhotos(_ images: [UIImage]) {
        let current = isEditing ? photoPathsEditing : photoPaths
        let remain = max(0, AppMedia.maxPhotosPerVisit - current.count)
        guard remain > 0 else { return }
        let picked = images.prefix(remain)

        for ui in picked {
            if let saved = try? ImageStore.save(ui) {
                if isEditing {
                    photoPathsEditing.append(saved)
                    if !originalPhotoPaths.contains(saved) {
                        pendingAdds.insert(saved)  // キャンセル時に掃除
                    }
                } else {
                    // 新規作成：保存用配列とUI用配列の両方に積む
                    photoPaths.append(saved)
                    photoPathsEditing.append(saved)
                }
            }
        }
    }


    func removePhoto(at index: Int) {
        if isEditing {
            guard photoPathsEditing.indices.contains(index) else { return }
            let path = photoPathsEditing.remove(at: index)

            if pendingAdds.contains(path) {
                ImageStore.delete(path)
                pendingAdds.remove(path)
            } else if originalPhotoPaths.contains(path) {
                pendingDeletes.insert(path) // 保存時に削除確定
            }
        } else {
            // 新規作成：UIと保存用を両方から削除
            guard photoPathsEditing.indices.contains(index) else { return }
            let path = photoPathsEditing.remove(at: index)

            if let i = photoPaths.firstIndex(of: path) {
                photoPaths.remove(at: i)
            }
            ImageStore.delete(path)
        }
    }


    // 保存せず閉じた場合の後処理（onDisappear などで呼ぶ）
    func discardPhotoEditingIfNeeded() {
        guard isEditing, didSave == false else { return }

        // セッション中に追加した画像を削除
        for path in pendingAdds {
            ImageStore.delete(path)
        }

        // 編集前の状態に戻す
        photoPathsEditing = originalPhotoPaths
        pendingAdds.removeAll()
        pendingDeletes.removeAll()
    }

}

// MARK: - Helpers
private extension String {
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}


