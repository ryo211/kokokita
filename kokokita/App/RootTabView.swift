import SwiftUI

enum RootTab: Hashable {
    case home      // 新しいHomeScreen
    case records   // 既存のVisitListScreen
    case center    // Kokokitaボタン
    case course    // 新しいCourseScreen
    case menu      // 既存のSettingsHomeScreen
}

/// 位置情報取得結果を保持する構造体
struct LocationData: Identifiable {
    var id: Date { timestamp }
    let timestamp: Date
    let latitude: Double
    let longitude: Double
    let accuracy: Double?
    let address: String?
    let flags: LocationSourceFlags
}

// Create画面に渡すデータ構造
struct CreateScreenData: Identifiable {
    var id: Date { locationData.timestamp }
    let locationData: LocationData
    let shouldOpenPOI: Bool
}

struct RootTabView: View {
    @State private var tab: RootTab = .home
    @State private var recording = RecordingController()
    @Environment(AppUIState.self) private var ui
    @Environment(AppModeManager.self) private var modeManager
    #if DEBUG
    private var debugSettings = DebugSettings.shared
    #endif

    var body: some View {
        // CoreDataの読み込み状態をチェック
        if !CoreDataStack.shared.isHealthy {
            // エラー画面を表示
            DataErrorView()
        } else {
            // 通常のUI
            normalTabView
        }
    }

    private var normalTabView: some View {
        // ← 重ねずに"占有する"縦積みレイアウトに変更
        VStack(spacing: 0) {
            // ===== コンテンツ領域（フッター分を除いた残り全体） =====
            ZStack(alignment: .bottomTrailing) {
                // 全ての画面を重ねて配置
                HomeScreen(
                    onKokokitaTap: {
                        recording.checkLocationPermissionAndCreate()
                    },
                    onViewAllTap: {
                        tab = .records
                    }
                )
                .opacity(tab == .home ? 1 : 0)
                .zIndex(tab == .home ? 1 : 0)

                NavigationStack { VisitListScreen() }
                    .opacity(tab == .records ? 1 : 0)
                    .zIndex(tab == .records ? 1 : 0)

                // CourseScreen は一時的に非表示（リリース後に復活予定）
                // CourseScreen()
                //     .opacity(tab == .course ? 1 : 0)
                //     .zIndex(tab == .course ? 1 : 0)

                NavigationStack { SettingsHomeScreen() }
                    .opacity(tab == .menu ? 1 : 0)
                    .zIndex(tab == .menu ? 1 : 0)

                // 記録画面のみ: 右下にフローティングボタン（地図シート・カレンダー表示中は非表示）
                if tab == .records && !ui.isMapSheetVisible && !ui.isCalendarVisible {
                    FloatingAtozukeButton {
                        recording.showManualEntrySheet = true
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                    .zIndex(999)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ===== フッター領域（バナー + カスタムタブバー） =====
            VStack(spacing: 0) {
                // 固定バナー（フッターの"上"に配置）
                #if DEBUG
                if debugSettings.isAdDisplayEnabled {
                    BannerAdView(adUnitID: bannerAdUnitID)
                        .background(.thinMaterial)
                        .transition(.opacity)
                }
                #else
                BannerAdView(adUnitID: bannerAdUnitID)
                    .background(.thinMaterial)
                    .transition(.opacity)
                #endif

                if !ui.isTabBarHidden {
                    CustomBottomBar(
                        current: tab,
                        onSelect: { tab = $0 },
                        onCenterTap: {
                            recording.checkLocationPermissionAndCreate()
                        },
                        onModeSwitch: {
                            modeManager.setMode(.pilgrimage)
                        }
                    )
                    .opacity(ui.tabBarOpacity)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            // ここまでが“常に表示される固定領域”
        }
        // 画面全体の背景（下は Safe Area を無視しない）
        .background(Color(.systemBackground))
        .animation(.snappy, value: ui.isTabBarHidden)
        // キーボードだけ下端を無視（入力用画面で下が切れないように）
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .recordingOverlay(recording)
        // タブ切り替え時にデータを更新（HomeScreenはopacityで切り替えのためonAppearが効かない）
        .onChange(of: tab) { _, newTab in
            if newTab == .home {
                NotificationCenter.default.post(name: .visitsChanged, object: nil)
            }
        }
        // 他タブからの地図フォーカスリクエストを処理
        .onChange(of: ui.mapFocusVisitId) { _, newId in
            if newId != nil {
                tab = .records
            }
        }
        // アプリ起動時にレビュー誘導の記録数を初期化（既存ユーザー対応）
        .task {
            await initializeAppReviewService()
        }
    }

    @MainActor
    private func initializeAppReviewService() async {
        let existingCount = (try? AppContainer.shared.repo.fetchAll(
            filterLabel: nil,
            filterGroup: nil,
            filterMember: nil,
            titleQuery: nil,
            dateFrom: nil,
            dateToExclusive: nil
        ).count) ?? 0
        AppReviewService.shared.initializeIfNeeded(existingRecordCount: existingCount)
    }
}

private struct CustomBottomBar: View {
    let current: RootTab
    let onSelect: (RootTab) -> Void
    let onCenterTap: () -> Void
    let onModeSwitch: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var footerOverlayColor: Color {
        colorScheme == .dark
            ? Color(.systemBackground).opacity(0.72)
            : Color.clear
    }

    private var modeSwitchColor: Color {
        colorScheme == .dark
            ? Color(red: 0.74, green: 0.70, blue: 1.0)
            : Color.indigo
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(colorScheme == .dark ? .regularMaterial : .ultraThinMaterial)
                .frame(height: UIConstants.Size.tabBarHeight)
                .overlay(footerOverlayColor)
                .overlay(Divider(), alignment: .top)

            HStack(spacing: 8) {
                // ккокита（記録）ボタン（左端）
                KokokitaTabActionButton(
                    imageName: "kokokita_irodori_blue_v2",
                    tintColor: .accentColor,
                    action: onCenterTap
                )

                // スライディングタブバー（記録モードの3タブ）
                SliderTabBar(
                    items: [
                        SliderTabBarItem(id: RootTab.home, icon: "house.fill", title: L.Tab.home),
                        SliderTabBarItem(id: RootTab.records, icon: "list.bullet", title: L.Tab.records),
                        SliderTabBarItem(id: RootTab.menu, icon: "ellipsis.circle.fill", title: L.Tab.menu),
                    ],
                    current: current,
                    onSelect: onSelect
                )

                // モード切り替えボタン（巡礼モードへ）
                Button {
                    onModeSwitch()
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "figure.walk")
                            .font(.title3)
                        Text(L.Tab.modePilgrimage)
                            .font(.caption2)
                    }
                    .foregroundStyle(modeSwitchColor.opacity(colorScheme == .dark ? 0.92 : 0.7))
                    .frame(width: 52, height: 52)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(modeSwitchColor.opacity(colorScheme == .dark ? 0.62 : 0.45), lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, UIConstants.Spacing.extraLarge + 8)
            .padding(.bottom, UIConstants.Spacing.medium)
        }
    }
}

// MARK: - Floating Atozuke Button (アトヅケボタン)

fileprivate struct FloatingAtozukeButton: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.orange.opacity(0.95),
                                Color.orange.opacity(0.75)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.25),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.orange.opacity(0.35), radius: 12, x: 0, y: 4)
                    .shadow(color: Color.orange.opacity(0.15), radius: 6, x: 0, y: 2)

                VStack(spacing: 2) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("＋追加")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L.ManualEntry.addManualEntry)
    }
}

private var bannerAdUnitID: String {
    #if DEBUG
    return "ca-app-pub-3940256099942544/2934735716"
    #else
    return "ca-app-pub-7495977536865069/2544041585"
    #endif
}
