import SwiftUI
import Observation

@Observable
final class AppUIState {
    var isTabBarHidden: Bool = false
    var tabBarOpacity: Double = 1.0
    var toolbarOpacity: Double = 1.0
}
