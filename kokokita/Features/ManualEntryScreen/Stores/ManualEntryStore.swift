import Foundation
import CoreLocation
import UIKit
import Observation
import PhotosUI

/// 後付け記録画面のStore
@MainActor
@Observable
final class ManualEntryStore {

    // MARK: - Inputs (表示・編集用)
    var timestampDisplay: Date = Date()
    var latitude: Double?
    var longitude: Double?
    var accuracy: Double?
    var addressLine: String?

    var title: String = ""
    var facilityName: String?
    var facilityAddress: String?
    var facilityCategory: String?
    var comment: String = ""
    var labelIds: Set<UUID> = []
    var groupId: UUID?
    var memberIds: Set<UUID> = []

    // MARK: - UI State
    var alert: String?
    var showLocationSearchSheet = false
    var showMapPickerSheet = false
    var showDatePicker = false
    var isPhotoImported = false

    // MARK: - Dependencies (Services)
    private let repo: CoreDataVisitRepository
    private let geocoder = CLGeocoder()

    // MARK: - Dependencies (Effects)

    /// 写真管理の副作用
    let photoEffects: PhotoEffects

    /// POI検索の副作用
    let poiEffects: POIEffects

    // MARK: - Initialization

    init(
        repo: CoreDataVisitRepository = AppContainer.shared.repo,
        poi: MapKitPlaceLookupService = AppContainer.shared.poi
    ) {
        self.repo = repo
        self.photoEffects = PhotoEffects()
        self.poiEffects = POIEffects(poiService: poi)
    }

    // MARK: - Validation

    /// 保存可能かどうか
    var canSave: Bool {
        hasValidLocation && hasValidTimestamp
    }

    /// 有効な位置情報があるか
    var hasValidLocation: Bool {
        guard let lat = latitude, let lon = longitude else { return false }
        return lat != 0 || lon != 0
    }

    /// 有効な日時か（未来でない）
    var hasValidTimestamp: Bool {
        timestampDisplay <= Date()
    }

    /// 位置情報の要約テキスト
    var locationSummary: String? {
        guard hasValidLocation else { return nil }
        if let addr = addressLine, !addr.isEmpty {
            return addr
        }
        guard let lat = latitude, let lon = longitude else { return nil }
        return String(format: "%.5f, %.5f", lat, lon)
    }

    // MARK: - EXIF Import

    /// PHPickerResultから情報を抽出
    func importFromPHPickerResult(_ result: PHPickerResult) async {
        // アセット識別子を取得
        guard let assetId = result.assetIdentifier else {
            // 識別子がない場合は画像データから直接抽出を試みる
            await importFromImageData(result)
            return
        }

        // PHAssetを取得
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
        guard let asset = fetchResult.firstObject else {
            await importFromImageData(result)
            return
        }

        // EXIFデータを抽出
        let exifData = await ExifEffects.extractExifData(from: asset)

        // 座標を設定
        if let coord = exifData.coordinate {
            self.latitude = coord.latitude
            self.longitude = coord.longitude
            // 逆ジオコーディングで住所を取得
            await reverseGeocode(latitude: coord.latitude, longitude: coord.longitude)
        }

        // 撮影日時を設定（未来でない場合のみ）
        if let timestamp = exifData.timestamp, timestamp <= Date() {
            self.timestampDisplay = timestamp
        }

        // 写真を追加
        await addPhotoFromPicker(result)

        isPhotoImported = true
    }

    /// 画像データから直接EXIFを抽出
    private func importFromImageData(_ result: PHPickerResult) async {
        do {
            guard let data = try await ExifEffects.loadImageData(from: result) else {
                return
            }

            let exifData = ExifEffects.extractExifData(from: data)

            // 座標を設定
            if let coord = exifData.coordinate {
                self.latitude = coord.latitude
                self.longitude = coord.longitude
                await reverseGeocode(latitude: coord.latitude, longitude: coord.longitude)
            }

            // 撮影日時を設定
            if let timestamp = exifData.timestamp, timestamp <= Date() {
                self.timestampDisplay = timestamp
            }

            // 写真を追加
            await addPhotoFromPicker(result)

            isPhotoImported = true
        } catch {
            Logger.error("Failed to import from image data: \(error)")
        }
    }

    /// PHPickerResultから写真を追加
    private func addPhotoFromPicker(_ result: PHPickerResult) async {
        let itemProvider = result.itemProvider
        if itemProvider.canLoadObject(ofClass: UIImage.self) {
            do {
                let image = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UIImage?, Error>) in
                    itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: object as? UIImage)
                        }
                    }
                }
                if let img = image {
                    photoEffects.addPhotos([img])
                }
            } catch {
                Logger.error("Failed to load image: \(error)")
            }
        }
    }

    // MARK: - Location Methods

    /// 位置情報を設定
    func setLocation(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// 逆ジオコーディング
    func reverseGeocode(latitude: Double, longitude: Double) async {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                self.addressLine = formatAddress(from: placemark)
            }
        } catch {
            Logger.warning("Reverse geocoding failed: \(error)")
        }
    }

    /// 住所フォーマット
    private func formatAddress(from placemark: CLPlacemark) -> String {
        var components: [String] = []
        if let admin = placemark.administrativeArea { components.append(admin) }
        if let locality = placemark.locality { components.append(locality) }
        if let subLocality = placemark.subLocality { components.append(subLocality) }
        if let thoroughfare = placemark.thoroughfare { components.append(thoroughfare) }
        if let subThoroughfare = placemark.subThoroughfare { components.append(subThoroughfare) }
        return components.joined()
    }

    // MARK: - POI (ココカモ)

    func openPOI() async {
        guard let lat = latitude, let lon = longitude else {
            alert = L.ManualEntry.locationRequired
            return
        }
        do {
            try await poiEffects.searchAndShowPOI(latitude: lat, longitude: lon)
        } catch {
            alert = error.localizedDescription
        }
    }

    func applyPOI(_ poi: PlacePOI) {
        let data = poiEffects.getApplicableData(from: poi)
        self.title = data.title
        self.facilityName = data.facilityName
        self.facilityAddress = data.facilityAddress
        self.facilityCategory = data.facilityCategory
        poiEffects.closePOI()
    }

    /// POIシートを閉じる
    func closePOISheet() {
        poiEffects.closePOI()
    }

    /// POIシートを表示すべきかどうか
    var shouldShowPOISheet: Bool {
        poiEffects.showPOI && !poiEffects.poiList.isEmpty
    }

    // MARK: - Save

    /// 後付け記録を保存
    @discardableResult
    func save() -> Bool {
        guard canSave else {
            if !hasValidLocation {
                alert = L.ManualEntry.locationRequired
            } else if !hasValidTimestamp {
                alert = L.ManualEntry.futureDateNotAllowed
            }
            return false
        }

        guard let lat = latitude, let lon = longitude else {
            alert = L.ManualEntry.locationRequired
            return false
        }

        do {
            let id = UUID()

            // 後付け記録用のVisit（署名なし）
            let visit = Visit(
                id: id,
                timestampUTC: timestampDisplay,
                latitude: lat,
                longitude: lon,
                horizontalAccuracy: accuracy
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
                photoPaths: photoEffects.getCurrentPaths()
            )

            try repo.createManualEntry(visit: visit, details: details)

            // 記録変更を通知
            NotificationCenter.default.post(name: .visitsChanged, object: nil)

            return true
        } catch {
            alert = error.localizedDescription
            return false
        }
    }

    // MARK: - Taxonomy Helpers

    func createLabel(_ name: String) -> UUID? {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return nil }

        do {
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

    // MARK: - Photo Helpers

    func addPhotos(_ images: [UIImage]) {
        photoEffects.addPhotos(images)
    }

    func removePhoto(at index: Int) {
        photoEffects.removePhoto(at: index)
    }
}
