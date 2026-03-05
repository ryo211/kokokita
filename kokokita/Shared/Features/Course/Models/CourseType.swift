import Foundation

// コースの種別
enum CourseType: String, CaseIterable {
    /// 巡礼（聖地巡礼・世界遺産など）
    case pilgrimage = "pilgrimage"
    /// スタンプラリー
    case stampRally = "stamp_rally"
    /// マイリスト（ユーザー作成）
    case myList = "my_list"

    /// 表示名
    var displayName: String {
        switch self {
        case .pilgrimage: return L.Course.typePilgrimage
        case .stampRally: return L.Course.typeStampRally
        case .myList: return L.Course.typeMyList
        }
    }
}
