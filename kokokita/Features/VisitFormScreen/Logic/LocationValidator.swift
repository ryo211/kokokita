import Foundation

/// 位置情報の検証ロジック（純粋関数）
struct LocationValidator {

    /// 位置情報が偽装されているかどうかを判定
    /// - Parameter flags: 位置情報ソースフラグ
    /// - Returns: 偽装されている場合true
    func isSimulated(_ flags: LocationSourceFlags) -> Bool {
        return flags.isSimulatedBySoftware == true || flags.isProducedByAccessory == true
    }

    /// 座標が有効かどうかを判定（0,0 以外）
    /// - Parameters:
    ///   - latitude: 緯度
    ///   - longitude: 経度
    /// - Returns: 有効な座標の場合true
    func isValidCoordinate(latitude: Double, longitude: Double) -> Bool {
        return latitude != 0 || longitude != 0
    }
}
