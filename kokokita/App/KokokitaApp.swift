//
//  KokokitaApp.swift
//  kokokita
//
//  Created by 橋本遼 on 2025/09/20.
//

import SwiftUI

@main
struct KokokitaApp: App {
    init() {
        // Core Data スタック初期化は CoreDataStack.shared が内部で行うので特に何も不要
        // もし起動時にマイグレーションや初期データが必要ならここで呼ぶ
    }
    
    @StateObject private var uiState = AppUIState()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(uiState)
                .environment(\.managedObjectContext, CoreDataStack.shared.context)
        }
    }
}
