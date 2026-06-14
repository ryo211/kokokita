import SwiftUI

@main
struct KokokitaApp: App {
    init() {
        // バンドルコースを DB に取り込む（初回起動時 + バージョン更新時に有効）
        do {
            try AppContainer.shared.courseJSONService.importBundledCoursesIfNeeded()
        } catch {
            Logger.error("バンドルコース取り込みエラー", error: error)
        }

        // ゴミ箱: 30日経過した記録を完全削除
        do {
            try AppContainer.shared.repo.cleanUpExpiredTrash()
        } catch {
            Logger.error("ゴミ箱の期限切れ記録の削除に失敗しました", error: error)
        }

        // 自動記録: 古い候補を削除してから監視開始
        AppContainer.shared.autoRecord.cleanUpOldCandidates()
        AppContainer.shared.autoRecord.startMonitoring()
    }

    @State private var uiState = AppUIState()
    @State private var spotFavoriteStore = SpotFavoriteStore()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(uiState)
                .environment(\.managedObjectContext, CoreDataStack.shared.context)
                .environment(\.spotFavoriteStore, spotFavoriteStore)
        }
    }
}
