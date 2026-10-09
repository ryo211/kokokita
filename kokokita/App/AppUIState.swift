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
    /// 記録詳細画面で写真ライトボックスが開いているかどうか
    /// （RootTabViewの手動記録フローティングボタンをライトボックスより手前に出さないための制御用）
    var isPhotoLightboxVisible: Bool = false
    /// 地図画面で特定の訪問記録にフォーカスするリクエスト（他タブからの遷移用）
    var mapFocusVisitId: UUID? = nil
    /// 現在選択中のブック
    var currentBook: Book? = nil
}
