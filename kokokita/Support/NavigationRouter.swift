//
//  NavigationRouter.swift
//  kokokita
//
//  Created by 橋本遼 on 2025/09/25.
//

import SwiftUI
import Observation

@Observable
final class NavigationRouter {
    var path = NavigationPath()
    func popToRoot() { path = NavigationPath() }
}
