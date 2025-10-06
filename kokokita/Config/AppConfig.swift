//
//  AppConfig.swift
//  kokokita
//
//  Created by 橋本遼 on 2025/09/20.
//

import Foundation
import CoreLocation

struct AppConfig {
    static let poiSearchRadius: CLLocationDistance = 100
    static let dateDisplayFormat = "yyyy/MM/dd HH:mm:ss"
    static let storageFileName = "kokokita_store.json"
}
