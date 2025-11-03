import Foundation
import CoreLocation

/// 地図アプリのURL生成（純粋関数）
struct MapURLBuilder {

    // MARK: - Apple Maps

    /// Apple Maps用URLを生成
    static func buildAppleMapsURL(
        coordinate: CLLocationCoordinate2D,
        label: String = "ココキタ"
    ) -> URL? {
        let urlString = "http://maps.apple.com/?ll=\(coordinate.latitude),\(coordinate.longitude)&q=\(label)"
        return URL(string: urlString)
    }

    // MARK: - Google Maps

    /// Google Mapsアプリ用URLを生成
    static func buildGoogleMapsAppURL(coordinate: CLLocationCoordinate2D) -> URL? {
        let urlString = "comgooglemaps://?q=\(coordinate.latitude),\(coordinate.longitude)&center=\(coordinate.latitude),\(coordinate.longitude)&zoom=15"
        return URL(string: urlString)
    }

    /// Google Mapsウェブ用URLを生成（フォールバック）
    static func buildGoogleMapsWebURL(coordinate: CLLocationCoordinate2D) -> URL? {
        let urlString = "https://www.google.com/maps/search/?api=1&query=\(coordinate.latitude),\(coordinate.longitude)"
        return URL(string: urlString)
    }
}
