import Foundation
import CoreLocation

struct AppConfig {
    static let poiSearchRadius: CLLocationDistance = 100
    static let dateDisplayFormat = "yyyy/MM/dd HH:mm:ss"
    static let storageFileName = "kokokita_store.json"

    // MARK: - Map Display Settings
    /// 地図の表示範囲（メートル）- 詳細画面・共有画像で共通
    static let mapDisplayRadius: CLLocationDistance = 5000
    /// 座標表示の小数点桁数
    static let coordinateDecimals: Int = 5
    /// 地図の角丸半径
    static let mapCornerRadius: CGFloat = 12

    // MARK: - Media Settings
    /// JPEG圧縮品質（0.0 - 1.0）
    static let imageCompressionQuality: CGFloat = 0.9
    /// 写真保存ディレクトリ名
    static let photoDirectoryName = "Photos"
    /// 1つの訪問記録に添付できる最大写真枚数
    static let maxPhotosPerVisit = 4

    // MARK: - Location Services
    /// 位置情報の精度設定
    /// - kCLLocationAccuracyBest: ±5m精度、取得に5-10秒（高精度ナビゲーション用）
    /// - kCLLocationAccuracyNearestTenMeters: ±10m精度、取得に1-3秒（訪問記録に最適）
    static let locationAccuracy: CLLocationAccuracy = kCLLocationAccuracyNearestTenMeters
    /// 位置情報取得のタイムアウト（秒）
    static let locationTimeout: TimeInterval = 30

    // MARK: - Share Settings
    /// 共有画像の論理サイズ（width）
    static let shareImageLogicalWidth: CGFloat = 360
    /// 共有画像の論理サイズ（height）
    static let shareImageLogicalHeight: CGFloat = 450
    /// 共有画像のスケール（最終的に width * scale の解像度になる）
    static let shareImageScale: CGFloat = 3
}
