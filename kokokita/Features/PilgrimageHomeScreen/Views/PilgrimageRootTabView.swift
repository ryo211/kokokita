import SwiftUI

// 巡礼モードのルートタブビュー（3タブ: ホーム / マップ / メニュー）
struct PilgrimageRootTabView: View {
    @EnvironmentObject private var modeManager: AppModeManager
    @State private var tab: PilgrimageTab = .home

    var body: some View {
        TabView(selection: $tab) {
            PilgrimageHomeView()
                .tabItem {
                    Label(L.Tab.home, systemImage: "house.fill")
                }
                .tag(PilgrimageTab.home)

            CourseMapPlaceholderView()
                .tabItem {
                    Label(L.Tab.records, systemImage: "map.fill")
                }
                .tag(PilgrimageTab.map)

            PilgrimageMenuView()
                .tabItem {
                    Label(L.Tab.menu, systemImage: "line.3.horizontal")
                }
                .tag(PilgrimageTab.menu)
        }
    }
}

enum PilgrimageTab: Hashable {
    case home
    case map
    case menu
}

// コースマップはPhase 3で実装 - 暫定プレースホルダー
private struct CourseMapPlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "map")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(L.Course.comingSoon)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(L.Tab.records)
    }
}

// 巡礼モードのメニュービュー
private struct PilgrimageMenuView: View {
    @EnvironmentObject private var modeManager: AppModeManager

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        modeManager.setMode(.record)
                    } label: {
                        Label(L.ModeSelection.switchToRecord, systemImage: "mappin.circle")
                    }
                } header: {
                    Text(L.ModeSelection.appModeSection)
                }
            }
            .navigationTitle(L.Menu.title)
        }
    }
}
