import SwiftUI
import Observation

@Observable
final class AppUIState {
    var isTabBarHidden: Bool = false
    var tabBarOpacity: Double = 1.0
    var toolbarOpacity: Double = 1.0
    /// 地図画面で記録カードが表示されているかどうか
    var isMapSheetVisible: Bool = false
    /// カレンダー表示モードかどうか
    var isCalendarVisible: Bool = false
}
