import Foundation

// コースに付与できるカテゴリ（複数選択可）
enum CourseCategory: String, CaseIterable, Codable {
    case historyCulture = "history_culture"
    case sightseeing    = "sightseeing"
    case architecture   = "architecture"
    case nature         = "nature"
    case anime          = "anime"
    case art            = "art"
    case other          = "other"

    var displayName: String {
        switch self {
        case .historyCulture: return L.Course.categoryHistoryCulture
        case .sightseeing:    return L.Course.categorySightseeing
        case .architecture:   return L.Course.categoryArchitecture
        case .nature:         return L.Course.categoryNature
        case .anime:          return L.Course.categoryAnime
        case .art:            return L.Course.categoryArt
        case .other:          return L.Course.categoryOther
        }
    }

    /// SF Symbols アイコン名
    var iconName: String {
        switch self {
        case .historyCulture: return "building.columns"
        case .sightseeing:    return "mappin.and.ellipse"
        case .architecture:   return "building.2"
        case .nature:         return "leaf"
        case .anime:          return "sparkles"
        case .art:            return "paintpalette"
        case .other:          return "tag"
        }
    }
}
