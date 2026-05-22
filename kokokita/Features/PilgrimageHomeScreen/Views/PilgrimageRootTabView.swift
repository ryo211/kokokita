import SwiftUI

// 巡礼モードのルートタブビュー（3タブ: ホーム / コース / マイリスト）
// 記録モードと同じカスタムタブバー UI を使用
struct PilgrimageRootTabView: View {
    @Environment(AppModeManager.self) private var modeManager
    @State private var tab: PilgrimageTab = .home
    @State private var recording = RecordingController()
    /// CourseScreen と共有するストア（NEWバッジ連動用）
    @State private var courseStore = CourseListStore()
    /// コースタブの赤ポチ（タブをタップで消える、コース一覧NEWバッジとは独立）
    @State private var showCourseTabBadge = false
    /// 飛翔アニメーション実行中フラグ
    @State private var isFlyAnimating = false
    /// マイリストタブのグローバルフレーム
    @State private var myListTabFrame: CGRect = .zero
    /// コースタブのグローバルフレーム
    @State private var courseTabFrame: CGRect = .zero
    /// 親 ZStack のグローバルフレーム（ローカル変換用）
    @State private var rootFrame: CGRect = .zero

    #if DEBUG
    private var debugSettings = DebugSettings.shared
    #endif

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // コンテンツ領域
                ZStack {
                    PilgrimageHomeView()
                        .opacity(tab == .home ? 1 : 0)
                        .zIndex(tab == .home ? 1 : 0)

                    CourseScreen(externalStore: courseStore)
                        .opacity(tab == .map ? 1 : 0)
                        .zIndex(tab == .map ? 1 : 0)

                    SpotListScreen()
                        .opacity(tab == .spotList ? 1 : 0)
                        .zIndex(tab == .spotList ? 1 : 0)

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
                        showCourseTabBadge: showCourseTabBadge,
                        onSelect: { newTab in
                            let prev = tab
                            tab = newTab
                            if newTab == .map {
                                // コースタブに入ったら赤ポチだけ消す
                                // コース一覧のNEWバッジはそのまま表示し続ける
                                withAnimation { showCourseTabBadge = false }
                            } else if prev == .map {
                                // コースタブから離れたらNEWバッジをクリア
                                courseStore.newlyAddedCourseIds.removeAll()
                            }
                        },
                        onRecord: {
                            recording.checkLocationPermissionAndCreate()
                        },
                        onModeSwitch: { modeManager.setMode(.record) },
                        onMyListTabFrame: { myListTabFrame = $0 },
                        onCourseTabFrame: { courseTabFrame = $0 }
                    )
                }
            }
            // ルートフレームを取得（グローバル→ローカル変換用）
            .background(
                GeometryReader { geo in
                    Color.clear.onAppear { rootFrame = geo.frame(in: .global) }
                }
            )

            // 飛翔アイコン（フルスクリーン ZStack の上に重ねる）
            if isFlyAnimating {
                FlyingIconView(
                    start: toLocal(myListTabFrame),
                    end: toLocal(courseTabFrame),
                    onComplete: {
                        isFlyAnimating = false
                        withAnimation(.spring(duration: 0.4)) {
                            showCourseTabBadge = true
                        }
                    }
                )
                .allowsHitTesting(false)
            }
        }
        .recordingOverlay(recording)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onReceive(NotificationCenter.default.publisher(for: .courseEnabled)) { notification in
            guard let _ = notification.object as? UUID else { return }
            triggerCourseEnabledEffect()
        }
    }

    // MARK: - 座標変換

    /// グローバル座標 → rootFrame 内のローカル座標
    private func toLocal(_ globalRect: CGRect) -> CGPoint {
        CGPoint(
            x: globalRect.midX - rootFrame.minX,
            y: globalRect.midY - rootFrame.minY
        )
    }

    // MARK: - 有効化エフェクト

    private func triggerCourseEnabledEffect() {
        if !myListTabFrame.isEmpty && !courseTabFrame.isEmpty {
            // フレームが取得できていれば飛翔アニメーション → アニメ完了後に赤ポチ
            isFlyAnimating = true
        } else {
            // フレーム未取得の場合は即座に赤ポチ
            withAnimation(.spring(duration: 0.4)) {
                showCourseTabBadge = true
            }
        }
    }
}

enum PilgrimageTab: Hashable {
    case home
    case map
    case spotList
    case myList
}

// MARK: - 飛翔アイコンビュー

private struct FlyingIconView: View {
    let start: CGPoint
    let end: CGPoint
    let onComplete: () -> Void

    @State private var progress: CGFloat = 0

    private let duration: Double = 0.55

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color.indigo.opacity(0.95), Color.indigo.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 30, height: 30)
            .overlay {
                Image("kokokita_irodori_white")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
            }
            .shadow(color: Color.indigo.opacity(0.4), radius: 8, x: 0, y: 2)
            .scaleEffect(1.0 - progress * 0.4)
            .opacity(progress < 0.8 ? 1.0 : (1.0 - (progress - 0.8) / 0.2))
            .position(bezierPoint(t: progress))
            .onAppear {
                withAnimation(.easeIn(duration: duration)) {
                    progress = 1.0
                }
                Task {
                    try? await Task.sleep(for: .seconds(duration))
                    await MainActor.run { onComplete() }
                }
            }
    }

    /// 二次ベジェ曲線（出発点から到達点まで、中間でやや上に膨らむ）
    private func bezierPoint(t: CGFloat) -> CGPoint {
        let ctrl = CGPoint(
            x: (start.x + end.x) / 2,
            y: min(start.y, end.y) - 50
        )
        let x = (1 - t) * (1 - t) * start.x + 2 * (1 - t) * t * ctrl.x + t * t * end.x
        let y = (1 - t) * (1 - t) * start.y + 2 * (1 - t) * t * ctrl.y + t * t * end.y
        return CGPoint(x: x, y: y)
    }
}

// MARK: - 巡礼モードのボトムバー

private struct PilgrimageBottomBar: View {
    let current: PilgrimageTab
    let showCourseTabBadge: Bool
    let onSelect: (PilgrimageTab) -> Void
    let onRecord: () -> Void
    let onModeSwitch: () -> Void
    let onMyListTabFrame: (CGRect) -> Void
    let onCourseTabFrame: (CGRect) -> Void
    @Environment(\.colorScheme) private var colorScheme

    private let tabItems: [(PilgrimageTab, String, String)] = [
        (.home, "house.fill", L.Tab.home),
        (.map, "map", L.Tab.course),
        (.spotList, "mappin.and.ellipse", L.Tab.spotList),
        (.myList, "plus.square.on.square", L.Tab.create),
    ]

    private var footerOverlayColor: Color {
        colorScheme == .dark
            ? Color(.systemBackground).opacity(0.72)
            : Color.clear
    }

    private var modeSwitchColor: Color {
        colorScheme == .dark
            ? Color.accentColor.opacity(0.92)
            : Color.accentColor
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
                    imageName: "kokokita_irodori_indigo_v2",
                    tintColor: colorScheme == .dark ? Color(red: 0.74, green: 0.70, blue: 1.0) : Color.indigo,
                    action: onRecord
                )

                // カスタムタブバー（フレーム取得付き）
                CustomTabBar(
                    items: tabItems,
                    current: current,
                    showCourseTabBadge: showCourseTabBadge,
                    onSelect: onSelect,
                    onMyListTabFrame: onMyListTabFrame,
                    onCourseTabFrame: onCourseTabFrame
                )

                // モード切り替えボタン（記録モードへ）
                Button {
                    onModeSwitch()
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "mappin.circle")
                            .font(.title3)
                        Text(L.Tab.modeRecord)
                            .font(.caption2)
                    }
                    .foregroundStyle(modeSwitchColor.opacity(colorScheme == .dark ? 1.0 : 0.7))
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

// MARK: - カスタムタブバー（フレーム取得付き）

private struct CustomTabBar: View {
    let items: [(PilgrimageTab, String, String)]
    let current: PilgrimageTab
    let showCourseTabBadge: Bool
    let onSelect: (PilgrimageTab) -> Void
    let onMyListTabFrame: (CGRect) -> Void
    let onCourseTabFrame: (CGRect) -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var tintColor: Color {
        colorScheme == .dark ? Color(red: 0.74, green: 0.70, blue: 1.0) : Color.indigo
    }

    private var containerOverlay: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color(.secondarySystemBackground).opacity(0.86),
                    Color(.tertiarySystemBackground).opacity(0.68)
                ]
                : [
                    Color.white.opacity(0.12),
                    Color.white.opacity(0.04)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var containerBorder: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color.white.opacity(0.16),
                    Color.white.opacity(0.05)
                ]
                : [
                    Color.white.opacity(0.2),
                    Color.white.opacity(0.08)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var indicatorFill: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    tintColor.opacity(0.34),
                    tintColor.opacity(0.18)
                ]
                : [
                    tintColor.opacity(0.15),
                    tintColor.opacity(0.08)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var indicatorBorder: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    tintColor.opacity(0.62),
                    tintColor.opacity(0.26)
                ]
                : [
                    tintColor.opacity(0.3),
                    tintColor.opacity(0.15)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var inactiveForeground: Color {
        colorScheme == .dark ? Color.primary.opacity(0.64) : Color.primary.opacity(0.5)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // 背景
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(colorScheme == .dark ? .regularMaterial : .ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(containerOverlay)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(
                                containerBorder,
                                lineWidth: 0.5
                            )
                    }
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.32 : 0.1), radius: 8, x: 0, y: 3)

                let tabCount = CGFloat(items.count)
                let tabWidth = max((geo.size.width - 16) / tabCount, 0)
                let currentIndex = items.firstIndex(where: { $0.0 == current }) ?? 0

                // スライディングインジケーター
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(colorScheme == .dark ? .thinMaterial : .ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(indicatorFill)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                indicatorBorder,
                                lineWidth: 1
                            )
                    }
                    .frame(width: tabWidth, height: max(geo.size.height - 12, 0))
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.24 : 0.08), radius: 6, x: 0, y: 2)
                    .offset(x: 6 + CGFloat(currentIndex) * tabWidth)
                    .animation(.interpolatingSpring(stiffness: 150, damping: 18), value: current)

                // ボタン
                HStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, tabItem in
                        let (tabId, icon, title) = tabItem
                        Button {
                            onSelect(tabId)
                        } label: {
                            ZStack {
                                VStack(spacing: 3) {
                                    Image(systemName: icon)
                                        .font(.title3)
                                        .fontWeight(current == tabId ? .semibold : .regular)
                                    Text(title)
                                        .font(.caption2)
                                        .fontWeight(current == tabId ? .semibold : .regular)
                                }
                                .foregroundStyle(current == tabId ? tintColor : inactiveForeground)
                                .frame(width: tabWidth)

                                // コースタブ（.map）の赤ポチバッジ
                                if tabId == .map && showCourseTabBadge {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 10, y: -12)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .background(
                            GeometryReader { tabGeo in
                                Color.clear.onAppear {
                                    let frame = tabGeo.frame(in: .global)
                                    if tabId == .map {
                                        onCourseTabFrame(frame)
                                    } else if tabId == .myList {
                                        onMyListTabFrame(frame)
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(6)
            }
        }
        .frame(height: 64)
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
