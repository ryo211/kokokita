import Foundation

extension Notification.Name {
    /// 訪問記録が変更されたことを通知
    static let visitsChanged = Notification.Name("visitsChanged")
    /// タクソノミー（ラベル・グループ）が変更されたことを通知
    static let taxonomyChanged = Notification.Name("taxonomyChanged")
    /// コースのチェックイン状態が変更されたことを通知
    static let courseChanged = Notification.Name("courseChanged")
    /// 新規コースがダウンロードされたことを通知（object: UUID = コースID）
    static let courseDownloaded = Notification.Name("courseDownloaded")
    /// 自作コースが有効化されたことを通知（object: UUID = コースID）
    static let courseEnabled = Notification.Name("courseEnabled")
}
