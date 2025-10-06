//
//  Untitled.swift
//  kokokita
//
//  Created by 橋本遼 on 2025/09/25.
//

import SwiftUI

final class NavigationRouter: ObservableObject {
    @Published var path = NavigationPath()
    func popToRoot() { path = NavigationPath() }
}
