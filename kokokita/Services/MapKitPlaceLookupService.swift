//
//  MapKitPlaceLookupService.swift
//  kokokita
//
//  Created by 橋本遼 on 2025/09/20.
//

// Services/MapKitPlaceLookupService.swift
import Foundation
import MapKit
import Contacts

final class MapKitPlaceLookupService: PlaceLookupService {
    func nearbyPOI(center: CLLocationCoordinate2D, radius: CLLocationDistance) async throws -> [PlacePOI] {

        // 正: center/radius で初期化（init() は使わない）
        let poiRequest = MKLocalPointsOfInterestRequest(center: center, radius: radius)
        poiRequest.pointOfInterestFilter = .includingAll  // 任意。未設定でも全POI対象

        // 正: MKLocalSearch は POI リクエストをそのまま受け取る
        let search = MKLocalSearch(request: poiRequest)
        let response = try await search.start()

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
    }
}

private extension CNPostalAddress {
    func formatted() -> String {
        [postalCode, country, state, city, street]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}
