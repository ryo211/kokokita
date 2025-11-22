import MapKit

extension MKPointOfInterestCategory {
    /// 全ての利用可能なPOIカテゴリを取得
    static var allCases: [MKPointOfInterestCategory] {
        return [
            .airport, .amusementPark, .aquarium, .atm, .automotiveRepair,
            .bakery, .bank, .beach, .beauty, .brewery,
            .cafe, .campground, .carRental, .evCharger, .fireStation,
            .fitnessCenter, .foodMarket, .gasStation, .hospital, .hotel,
            .landmark, .laundry, .library, .mailbox, .marina,
            .movieTheater, .museum, .nationalPark, .nightlife, .park,
            .parking, .pharmacy, .police, .postOffice, .publicTransport,
            .restaurant, .restroom, .school, .spa, .stadium,
            .store, .theater, .university, .winery, .zoo
        ]
    }

    /// ローカライズされた名前（日本語/英語）
    var localizedName: String {
        let isJapanese = Locale.current.language.languageCode?.identifier == "ja"
        return isJapanese ? japaneseName : englishName
    }

    private var japaneseName: String {
        switch self {
        case .airport:         return "空港"
        case .amusementPark:   return "遊園地"
        case .aquarium:        return "水族館"
        case .atm:             return "ATM"
        case .automotiveRepair: return "自動車修理店"
        case .bakery:          return "ベーカリー"
        case .bank:            return "銀行"
        case .beach:           return "ビーチ"
        case .beauty:           return "美容室"
        case .brewery:         return "ブルワリー"
        case .cafe:            return "カフェ"
        case .campground:      return "キャンプ場"
        case .carRental:       return "レンタカー"
        case .evCharger:       return "EV充電スタンド"
        case .fireStation:     return "消防署"
        case .fitnessCenter:   return "フィットネス"
        case .foodMarket:      return "食品マーケット"
        case .gasStation:      return "ガソリンスタンド"
        case .hospital:        return "病院"
        case .hotel:           return "ホテル"
        case .landmark:        return "ランドマーク"
        case .laundry:         return "コインランドリー"
        case .library:         return "図書館"
        case .mailbox:         return "郵便ポスト"
        case .marina:          return "マリーナ"
        case .movieTheater:    return "映画館"
        case .museum:          return "博物館"
        case .nationalPark:    return "国立公園"
        case .nightlife:       return "バー・クラブ"
        case .park:            return "公園"
        case .parking:         return "駐車場"
        case .pharmacy:        return "薬局"
        case .police:          return "警察署"
        case .postOffice:      return "郵便局"
        case .publicTransport: return "公共交通"
        case .restaurant:      return "飲食店"
        case .restroom:        return "トイレ"
        case .school:          return "学校"
        case .spa:             return "スパ"
        case .stadium:         return "スタジアム"
        case .store:           return "店舗"
        case .theater:         return "劇場"
        case .university:      return "大学"
        case .winery:          return "ワイナリー"
        case .zoo:             return "動物園"

        default:
            // 未来のカテゴリ or 未対応カテゴリ
            return rawValue.replacingOccurrences(of: "MKPOICategory", with: "")
        }
    }

    private var englishName: String {
        switch self {
        case .airport:         return "Airport"
        case .amusementPark:   return "Amusement Park"
        case .aquarium:        return "Aquarium"
        case .atm:             return "ATM"
        case .automotiveRepair: return "Auto Repair"
        case .bakery:          return "Bakery"
        case .bank:            return "Bank"
        case .beach:           return "Beach"
        case .beauty:           return "Beauty Salon"
        case .brewery:         return "Brewery"
        case .cafe:            return "Cafe"
        case .campground:      return "Campground"
        case .carRental:       return "Car Rental"
        case .evCharger:       return "EV Charger"
        case .fireStation:     return "Fire Station"
        case .fitnessCenter:   return "Fitness Center"
        case .foodMarket:      return "Food Market"
        case .gasStation:      return "Gas Station"
        case .hospital:        return "Hospital"
        case .hotel:           return "Hotel"
        case .landmark:        return "Landmark"
        case .laundry:         return "Laundry"
        case .library:         return "Library"
        case .mailbox:         return "Mailbox"
        case .marina:          return "Marina"
        case .movieTheater:    return "Movie Theater"
        case .museum:          return "Museum"
        case .nationalPark:    return "National Park"
        case .nightlife:       return "Nightlife"
        case .park:            return "Park"
        case .parking:         return "Parking"
        case .pharmacy:        return "Pharmacy"
        case .police:          return "Police Station"
        case .postOffice:      return "Post Office"
        case .publicTransport: return "Public Transport"
        case .restaurant:      return "Restaurant"
        case .restroom:        return "Restroom"
        case .school:          return "School"
        case .spa:             return "Spa"
        case .stadium:         return "Stadium"
        case .store:           return "Store"
        case .theater:         return "Theater"
        case .university:      return "University"
        case .winery:          return "Winery"
        case .zoo:             return "Zoo"

        default:
            // 未来のカテゴリ or 未対応カテゴリ
            return rawValue.replacingOccurrences(of: "MKPOICategory", with: "")
        }
    }

    /// アプリの3分類（飲食 / 観光 / その他）に正規化
    var kkCategory: KKCategory {
        switch self {
        // —— 飲食系
        case .restaurant, .cafe, .bakery, .brewery, .winery, .foodMarket, .nightlife:
            return .food

        // —— 観光系（“行って楽しむ/観る/遊ぶ”寄り）
        case .museum, .park, .nationalPark, .aquarium, .zoo, .landmark,
             .amusementPark, .stadium, .theater, .beach, .campground, .marina:
            return .sightseeing

        // —— それ以外はその他
        default:
            return .other
        }
    }
}

enum KKCategory: String, CaseIterable, Identifiable {
    case food
    case sightseeing
    case other

    var id: String { rawValue }

    var localizedName: String {
        let isJapanese = Locale.current.language.languageCode?.identifier == "ja"
        switch self {
        case .food:
            return isJapanese ? "飲食店" : "Food & Drink"
        case .sightseeing:
            return isJapanese ? "観光地" : "Sightseeing"
        case .other:
            return isJapanese ? "その他" : "Other"
        }
    }
}



//extension MKMapItem {
//    /// MKMapItem から KKCategory を取り出す（なければ nil）
//    var kkCategory: KKCategory? {
//        pointOfInterestCategory?.kkCategory ?? .other
//    }
//}
