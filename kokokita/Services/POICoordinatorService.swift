//
//  POICoordinatorService.swift
//  kokokita
//
//  Created by Claude on 2025/10/11.
//

import Foundation
import CoreLocation

/// POI検索とデータ適用を調整するサービス
@MainActor
final class POICoordinatorService: ObservableObject {

    // MARK: - Published State

    /// POIリスト表示フラグ
    @Published var showPOI = false

    /// 検索結果のPOIリスト
    @Published var poiList: [PlacePOI] = []

    // MARK: - Dependencies

    private let poiService: PlaceLookupService

    // MARK: - Initialization

    init(poiService: PlaceLookupService) {
        self.poiService = poiService
    }

    // MARK: - Search POI

    /// 周辺のPOIを検索してシートを表示
    func searchAndShowPOI(latitude: Double, longitude: Double) async throws {
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        poiList = try await poiService.nearbyPOI(center: center, radius: AppConfig.poiSearchRadius)
        showPOI = true
    }

    // MARK: - Apply POI

    /// 選択されたPOIの情報を返す（適用はViewModel側で行う）
    func getApplicableData(from poi: PlacePOI) -> (title: String, facilityName: String, facilityAddress: String?) {
        return (
            title: poi.name,
            facilityName: poi.name,
            facilityAddress: poi.address
        )
    }

    /// POIシートを閉じる
    func closePOI() {
        showPOI = false
    }
}
