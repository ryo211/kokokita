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

    /// 周辺のPOIを検索してシートを表示（リトライ機能付き）
    func searchAndShowPOI(latitude: Double, longitude: Double) async throws {
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

        // リトライ戦略：最大3回、指数バックオフ
        var lastError: Error?
        for attempt in 1...3 {
            do {
                poiList = try await poiService.nearbyPOI(center: center, radius: AppConfig.poiSearchRadius)
                showPOI = true
                return
            } catch {
                lastError = error

                // 最後の試行でなければ待機
                if attempt < 3 {
                    let delay = TimeInterval(attempt) * 0.5  // 0.5秒、1秒、1.5秒
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        // すべて失敗したら最後のエラーをthrow
        if let error = lastError {
            throw error
        }
    }

    // MARK: - Apply POI

    /// 選択されたPOIの情報を返す（適用はViewModel側で行う）
    func getApplicableData(from poi: PlacePOI) -> (title: String, facilityName: String, facilityAddress: String?, facilityCategory: String?) {
        return (
            title: poi.name,
            facilityName: poi.name,
            facilityAddress: poi.address,
            facilityCategory: poi.poiCategoryRaw
        )
    }

    /// POIシートを閉じる
    func closePOI() {
        showPOI = false
    }
}
