import Foundation
import Photos
import UIKit
import ImageIO
import CoreLocation
import PhotosUI
import SwiftUI

/// EXIFデータを抽出するユーティリティ
enum ExifEffects {
    /// EXIFから抽出されたデータ
    struct ExifData {
        let coordinate: CLLocationCoordinate2D?
        let timestamp: Date?
    }

    /// PHAssetからEXIFデータを抽出
    static func extractExifData(from asset: PHAsset) async -> ExifData {
        // 位置情報
        let coordinate = asset.location?.coordinate

        // 撮影日時（EXIFの撮影日を優先、なければアセット作成日）
        let timestamp = asset.creationDate

        return ExifData(coordinate: coordinate, timestamp: timestamp)
    }

    /// UIImageからEXIFデータを抽出（画像データを直接解析）
    static func extractExifData(from imageData: Data) -> ExifData {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return ExifData(coordinate: nil, timestamp: nil)
        }

        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return ExifData(coordinate: nil, timestamp: nil)
        }

        // GPS情報を抽出
        let coordinate: CLLocationCoordinate2D? = {
            guard let gpsDict = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any],
                  let latitude = gpsDict[kCGImagePropertyGPSLatitude as String] as? Double,
                  let latitudeRef = gpsDict[kCGImagePropertyGPSLatitudeRef as String] as? String,
                  let longitude = gpsDict[kCGImagePropertyGPSLongitude as String] as? Double,
                  let longitudeRef = gpsDict[kCGImagePropertyGPSLongitudeRef as String] as? String else {
                return nil
            }

            let lat = latitudeRef == "S" ? -latitude : latitude
            let lon = longitudeRef == "W" ? -longitude : longitude

            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }()

        // 撮影日時を抽出
        let timestamp: Date? = {
            // EXIFの撮影日時を取得
            guard let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] else {
                return nil
            }

            // DateTimeOriginal（元の撮影日時）を優先
            if let dateString = exifDict[kCGImagePropertyExifDateTimeOriginal as String] as? String {
                return parseExifDate(dateString)
            }

            // DateTimeDigitized（デジタル化日時）
            if let dateString = exifDict[kCGImagePropertyExifDateTimeDigitized as String] as? String {
                return parseExifDate(dateString)
            }

            return nil
        }()

        return ExifData(coordinate: coordinate, timestamp: timestamp)
    }

    /// EXIF日付文字列をDateに変換
    private static func parseExifDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: dateString)
    }

    /// PHPickerResultからフルイメージデータを取得
    static func loadImageData(from result: PHPickerResult) async throws -> Data? {
        return try await withCheckedThrowingContinuation { continuation in
            let itemProvider = result.itemProvider
            if itemProvider.canLoadObject(ofClass: UIImage.self) {
                itemProvider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: data)
                    }
                }
            } else {
                continuation.resume(returning: nil)
            }
        }
    }

    /// PhotosPickerItemからEXIFデータを抽出（複数の方法を試行）
    @MainActor
    static func extractExifDataFromPhotosPickerItem(_ item: PhotosPickerItem) async -> ExifData {
        // まずフォトライブラリへのアクセス権限を確認・要求
        let status = await requestPhotoLibraryAccess()

        // 方法1: itemIdentifierからPHAssetを取得（フルアクセス権限が必要）
        if status == .authorized || status == .limited {
            if let identifier = item.itemIdentifier {
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
                if let asset = fetchResult.firstObject {
                    let coordinate = asset.location?.coordinate
                    let timestamp = asset.creationDate
                    if coordinate != nil || timestamp != nil {
                        return ExifData(coordinate: coordinate, timestamp: timestamp)
                    }
                }
            }
        }

        // 方法2: 通常のData読み込みでEXIFを試行
        if let data = try? await item.loadTransferable(type: Data.self) {
            let exifData = extractExifData(from: data)
            if exifData.coordinate != nil || exifData.timestamp != nil {
                return exifData
            }
        }

        return ExifData(coordinate: nil, timestamp: nil)
    }

    /// フォトライブラリへのアクセス権限を要求
    private static func requestPhotoLibraryAccess() async -> PHAuthorizationStatus {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if currentStatus == .notDetermined {
            return await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        return currentStatus
    }
}
