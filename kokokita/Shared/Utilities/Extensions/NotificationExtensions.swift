import Foundation

extension Notification.Name {
    /// 訪問記録が変更されたことを通知
    static let visitsChanged = Notification.Name("visitsChanged")
    /// タクソノミー（ラベル・グループ）が変更されたことを通知
    static let taxonomyChanged = Notification.Name("taxonomyChanged")
}
