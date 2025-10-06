import Foundation
import CoreLocation
import Contacts

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
                resolvedAddress: addressLine
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
                // 住所を保存（表示用が入っていれば）
                if let addr = addressLine, !addr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    cur.resolvedAddress = addr
                }
            }
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

}

// MARK: - Helpers
private extension String {
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}


