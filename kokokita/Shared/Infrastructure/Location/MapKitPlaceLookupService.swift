import Foundation
import MapKit
import Contacts

struct MapKitPlaceLookupService {

    // レート制限を管理するActor（DI可能）
    private let rateLimiter: RateLimiter

    /// 初期化
    /// - Parameter rateLimiter: レート制限を管理するActor（デフォルト: 500ms間隔）
    init(rateLimiter: RateLimiter = RateLimiter(minimumInterval: 0.5)) {
        self.rateLimiter = rateLimiter
    }

    func nearbyPOI(center: CLLocationCoordinate2D, radius: CLLocationDistance) async throws -> [PlacePOI] {

        // 座標の妥当性チェック
        guard CLLocationCoordinate2DIsValid(center),
              center.latitude != 0 || center.longitude != 0 else {
            throw NSError(domain: "PlaceLookup", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "位置情報が不正です"])
        }

        // レート制限チェック（Actor経由）
        try await rateLimiter.waitIfNeeded()

        // 正: center/radius で初期化（init() は使わない）
        let poiRequest = MKLocalPointsOfInterestRequest(center: center, radius: radius)
        poiRequest.pointOfInterestFilter = .includingAll  // 任意。未設定でも全POI対象

        // 正: MKLocalSearch は POI リクエストをそのまま受け取る
        let search = MKLocalSearch(request: poiRequest)

        do {
            let response = try await search.start()

            // 結果が0件の場合の処理
            guard !response.mapItems.isEmpty else {
                throw NSError(domain: "PlaceLookup", code: -2,
                             userInfo: [NSLocalizedDescriptionKey: "周辺に施設が見つかりませんでした"])
            }

            return response.mapItems.map { item in
                let cat = item.pointOfInterestCategory?.rawValue.replacingOccurrences(of: "_", with: " ")
                // 住所は postalAddress があれば整形、無ければ placemark.title をフォールバック
                let addr = item.placemark.postalAddress?.formatted() ?? item.placemark.title

                let jpCategory = item.pointOfInterestCategory?.japaneseName
                return PlacePOI(
                    name: item.name ?? "不明",
                    category: jpCategory,
                    address: addr,
                    phone: item.phoneNumber,
                    poiCategoryRaw: cat
                )
            }
        } catch let error as NSError {
            // MKErrorDomain エラー2（検索失敗）の詳細を分析
            if error.domain == MKErrorDomain {
                switch error.code {
                case 2: // MKError.Code.placemarkNotFound
                    throw NSError(domain: "PlaceLookup", code: -2,
                                 userInfo: [NSLocalizedDescriptionKey: "周辺に施設が見つかりませんでした"])
                case 4: // MKError.Code.loadingThrottled
                    throw NSError(domain: "PlaceLookup", code: -3,
                                 userInfo: [NSLocalizedDescriptionKey: "リクエストが多すぎます。少し待ってから再度お試しください"])
                default:
                    throw NSError(domain: "PlaceLookup", code: error.code,
                                 userInfo: [NSLocalizedDescriptionKey: "施設検索に失敗しました: \(error.localizedDescription)"])
                }
            }
            throw error
        }
    }
}

private extension CNPostalAddress {
    func formatted() -> String {
        [postalCode, country, state, city, street]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}
