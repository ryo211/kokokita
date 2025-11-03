import SwiftUI
import Observation

@Observable
final class NavigationRouter {
    var path = NavigationPath()
    func popToRoot() { path = NavigationPath() }
}
