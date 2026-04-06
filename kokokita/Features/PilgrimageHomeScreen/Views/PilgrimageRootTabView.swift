import SwiftUI

// 巡礼モードのルートタブビュー（3タブ: ホーム / コース / マイリスト）
// 記録モードと同じカスタムタブバー UI を使用
struct PilgrimageRootTabView: View {
    @Environment(AppModeManager.self) private var modeManager
    @State private var tab: PilgrimageTab = .home
    @State private var recording = RecordingController()
    #if DEBUG
    private var debugSettings = DebugSettings.shared
    #endif

    var body: some View {
        VStack(spacing: 0) {
            // コンテンツ領域
            ZStack {
                PilgrimageHomeView()
                    .opacity(tab == .home ? 1 : 0)
                    .zIndex(tab == .home ? 1 : 0)

                CourseScreen()
                    .opacity(tab == .map ? 1 : 0)
                    .zIndex(tab == .map ? 1 : 0)

                NavigationStack {
                    MyListView()
                }
                .opacity(tab == .myList ? 1 : 0)
                .zIndex(tab == .myList ? 1 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // フッター（バナー広告 + カスタムタブバー）
            VStack(spacing: 0) {
                #if DEBUG
                if debugSettings.isAdDisplayEnabled {
                    BannerAdView(adUnitID: pilgrimageBannerAdUnitID)
                        .background(.thinMaterial)
                }
                #else
                BannerAdView(adUnitID: pilgrimageBannerAdUnitID)
                    .background(.thinMaterial)
                #endif

                PilgrimageBottomBar(
                    current: tab,
                    onSelect: { tab = $0 },
                    onRecord: {
                        recording.checkLocationPermissionAndCreate()
                    },
                    onModeSwitch: { modeManager.setMode(.record) }
                )
            }
        }
        .recordingOverlay(recording)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

enum PilgrimageTab: Hashable {
    case home
    case map
    case myList
}

// MARK: - 巡礼モードのボトムバー

private struct PilgrimageBottomBar: View {
    let current: PilgrimageTab
    let onSelect: (PilgrimageTab) -> Void
    let onRecord: () -> Void
    let onModeSwitch: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .frame(height: UIConstants.Size.tabBarHeight)
                .overlay(Divider(), alignment: .top)

            HStack(spacing: 8) {
                // ккокита（記録）ボタン（左端）
                Button(action: onRecord) {
                    VStack(spacing: 2) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.indigo.opacity(0.95), Color.indigo.opacity(0.75)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 38, height: 38)
                                .shadow(color: Color.indigo.opacity(0.35), radius: 6, x: 0, y: 2)
                            Image("kokokita_irodori_white")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 22, height: 22)
                        }
                        Text(L.App.name)
                            .font(.caption2.bold())
                            .foregroundStyle(Color.indigo)
                    }
                    .frame(width: 52, height: 52)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L.Tab.kokokita)

                // スライディングタブバー（巡礼モードの3タブ）
                SliderTabBar(
                    items: [
                        SliderTabBarItem(id: PilgrimageTab.home, icon: "house.fill", title: L.Tab.home),
                        SliderTabBarItem(id: PilgrimageTab.map, icon: "map", title: L.Tab.course),
                        SliderTabBarItem(id: PilgrimageTab.myList, icon: "person.text.rectangle", title: L.Tab.myList),
                    ],
                    current: current,
                    onSelect: onSelect,
                    tintColor: .indigo
                )

                // モード切り替えボタン（記録モードへ）
                Button {
                    onModeSwitch()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "mappin.circle")
                            .font(.title3)
                        Text(L.Tab.modeRecord)
                            .font(.caption2)
                    }
                    .foregroundStyle(Color.accentColor.opacity(0.7))
                    .frame(width: 52, height: 52)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.45), lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, UIConstants.Spacing.extraLarge + 8)
            .padding(.bottom, UIConstants.Spacing.medium)
        }
    }
}

// MARK: - 広告ユニットID

private var pilgrimageBannerAdUnitID: String {
    #if DEBUG
    return "ca-app-pub-3940256099942544/2934735716"
    #else
    return "ca-app-pub-7495977536865069/2544041585"
    #endif
}
