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
    }

    @State private var uiState = AppUIState()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(uiState)
                .environment(\.managedObjectContext, CoreDataStack.shared.context)
        }
    }
}
