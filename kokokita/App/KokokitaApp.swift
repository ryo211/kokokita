import SwiftUI

@main
struct KokokitaApp: App {
    init() {
        // ブック機能の初期化（デフォルトブック作成 + 既存データのマイグレーション）
        AppContainer.shared.setupBook(defaultName: "マイブック")

        // ゴミ箱: 30日経過した記録を完全削除
        do {
            try AppContainer.shared.repo.cleanUpExpiredTrash()
        } catch {
            Logger.error("ゴミ箱の期限切れ記録の削除に失敗しました", error: error)
        }

        // コース: syncSections/syncSpots の過去の不具合による重複セクション・スポットを統合
        // （Course画面を開く前に必ず解消しておく必要があるため、他のクリーンアップと同様に起動時に実行）
        do {
            try AppContainer.shared.courseRepo.cleanUpDuplicateSectionsAndSpots()
        } catch {
            Logger.error("コースの重複セクション・スポットの統合に失敗しました", error: error)
        }

        // 自動記録: 古い候補を削除してから監視開始
        AppContainer.shared.autoRecord.cleanUpOldCandidates()
        AppContainer.shared.autoRecord.startMonitoring()
    }

    @State private var uiState = AppUIState()
    @State private var spotFavoriteStore = SpotFavoriteStore()
    @State private var spotFolderStore = SpotFolderStore()
    @State private var courseFavoriteStore = CourseFavoriteStore()
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(uiState)
                .environment(\.managedObjectContext, CoreDataStack.shared.context)
                .environment(\.spotFavoriteStore, spotFavoriteStore)
                .environment(\.spotFolderStore, spotFolderStore)
                .environment(\.courseFavoriteStore, courseFavoriteStore)
                .task {
                    // ブック初期化後に AppUIState へ反映
                    uiState.currentBook = AppContainer.shared.currentBook
                    AppIconBadgeService.shared.syncAutoRecordCandidateCount()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        AppIconBadgeService.shared.syncAutoRecordCandidateCount()
                    }
                }
        }
    }
}
