import Foundation

// コースの種別
enum CourseType: String, CaseIterable {
    /// 世界遺産
    case worldHeritage = "world_heritage"
    /// 国宝・重要文化財
    case nationalTreasure = "national_treasure"
    /// アニメ聖地
    case animeSacredPlace = "anime_sacred_place"
    /// カスタム（ユーザー作成）
    case custom = "custom"

    /// 表示名（ローカライズキーはE4タスクで追加）
    var displayName: String {
        switch self {
        case .worldHeritage: return "世界遺産"
        case .nationalTreasure: return "国宝・重要文化財"
        case .animeSacredPlace: return "アニメ聖地"
        case .custom: return "カスタム"
        }
    }
}
