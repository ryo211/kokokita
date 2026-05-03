import Foundation

// コースに付与できるカテゴリ（複数選択可）
enum CourseCategory: String, CaseIterable, Codable {
    case historyCulture    = "history_culture"
    case nature            = "nature"
    case artEntertainment  = "art_entertainment"
    case movieDrama        = "movie_drama"
    case travelSightseeing = "travel_sightseeing"
    case anime             = "anime"
    case userCreated       = "user_created"

    var displayName: String {
        switch self {
        case .historyCulture:   return L.Course.categoryHistoryCulture
        case .nature:           return L.Course.categoryNature
        case .artEntertainment: return L.Course.categoryArtEntertainment
        case .movieDrama:       return L.Course.categoryMovieDrama
        case .travelSightseeing:return L.Course.categoryTravelSightseeing
        case .anime:            return L.Course.categoryAnime
        case .userCreated:      return L.Course.categoryUserCreated
        }
    }

    /// SF Symbols アイコン名
    var iconName: String {
        switch self {
        case .historyCulture:   return "building.columns"
        case .nature:           return "leaf"
        case .artEntertainment: return "theatermasks"
        case .movieDrama:       return "film"
        case .travelSightseeing:return "airplane"
        case .anime:            return "sparkles"
        case .userCreated:      return "person.crop.square"
        }
    }
}
