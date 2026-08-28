import SwiftUI

// 巡礼モードのルートタブビュー（3タブ: ホーム / コース / マイリスト）
// 記録モードと同じカスタムタブバー UI を使用
struct PilgrimageRootTabView: View {
    /// 現在このモードが表示中か（RootViewが両モードを常駐させているため、
    /// 非アクティブな間は広告バナーを不要にマウントしないよう判定する）
    let isActiveMode: Bool
    @Environment(AppModeManager.self) private var modeManager
    @Environment(AppUIState.self) private var ui
    @State private var tab: PilgrimageTab = .home
    @State private var recording = RecordingController()
    /// CourseScreen と共有するストア（NEWバッジ連動用）
    @State private var courseStore = CourseListStore()
    /// コースタブの赤ポチ（タブをタップで消える、コース一覧NEWバッジとは独立）
    @State private var showCourseTabBadge = false
    /// 自動記録候補がある場合、記録モード切り替えボタンに赤ポチを表示
    @State private var hasAutoRecordCandidates = false
    /// 飛翔アニメーション実行中フラグ
    @State private var isFlyAnimating = false
    /// マイリストタブのグローバルフレーム（飛翔アニメーション用）
    @State private var myListTabFrame: CGRect = .zero
    /// コースタブのグローバルフレーム（飛翔アニメーション用）
    @State private var courseTabFrame: CGRect = .zero
    /// 親 ZStack のグローバルフレーム（飛翔アニメーションのtoLocal()専用。コーチマークはrootSize/named spaceを使う）
    @State private var rootFrame: CGRect = .zero
    /// 記録ボタンのフレーム（"pilgrimageCoachmark"座標空間、コーチマーク位置計算用）
    @State private var recordButtonFrame: CGRect = .zero
    /// モード切替ボタンのフレーム（"pilgrimageCoachmark"座標空間、コーチマーク位置計算用）
    @State private var modeSwitchButtonFrame: CGRect = .zero
    /// 親 ZStack 自身のサイズ（"pilgrimageCoachmark"座標空間の原点は常に(0,0)なので、サイズだけ分かればよい）
    @State private var rootSize: CGSize = .zero
    /// ガイド付きツアー①完了（初回記録）。他画面（HomeScreen）とも共有するため@AppStorageで永続化する
    @AppStorage("coachmark.hasCompletedFirstRecord") private var hasCompletedFirstRecord = false
    /// ガイド付きツアー②完了（記録モードへの遷移）
    @AppStorage("coachmark.hasSwitchedToRecordMode") private var hasSwitchedToRecordMode = false
    /// コーチマークを閉じる（×）操作で二度と表示しないようにするフラグ。他画面とも共有する
    @AppStorage("coachmark.dismissed") private var isCoachmarkDismissed = false

    #if DEBUG
    private var debugSettings = DebugSettings.shared
    #endif

    // private な@Stateプロパティを含むため自動合成されるメンバーワイズイニシャライザが
    // privateになってしまう。isActiveModeだけを受け取る公開イニシャライザを明示的に用意する
    init(isActiveMode: Bool) {
        self.isActiveMode = isActiveMode
    }

    var body: some View {
        ZStack {
            // サイズ測定用（ZStackの直接の子として置くことで、確実にZStack自身のサイズを取得する。
            // .background(GeometryReader{...})による自己測定は.coordinateSpace(name:)のスコープと
            // 噛み合わないことがあり、原点が(0,0)にならないバグの原因になっていた）
            GeometryReader { geo in
                Color.clear
                    .onAppear { rootSize = geo.size }
                    .onChange(of: geo.size) { _, newSize in rootSize = newSize }
            }

            VStack(spacing: 0) {
                // コンテンツ領域
                ZStack {
                    PilgrimageHomeView()
                        .opacity(tab == .home ? 1 : 0)
                        .zIndex(tab == .home ? 1 : 0)

                    CourseScreen(store: courseStore)
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
                if !ui.isTabBarHidden {
                    VStack(spacing: 0) {
                        #if DEBUG
                        if debugSettings.isAdDisplayEnabled && !PremiumManager.shared.isPremium && isActiveMode {
                            BannerAdView(adUnitID: pilgrimageBannerAdUnitID)
                                .background(.thinMaterial)
                        }
                        #else
                        if !PremiumManager.shared.isPremium && isActiveMode {
                            BannerAdView(adUnitID: pilgrimageBannerAdUnitID)
                                .background(.thinMaterial)
                        }
                        #endif

                        PilgrimageBottomBar(
                            current: tab,
                            showCourseTabBadge: showCourseTabBadge,
                            onSelect: { newTab in
                                let prev = tab
                                tab = newTab
                                if newTab == .map {
                                    // コースタブに入ったら赤ポチだけ消す
                                    withAnimation { showCourseTabBadge = false }
                                }
                            },
                            onRecord: {
                                recording.checkLocationPermissionAndCreate()
                            },
                            showRecordModeBadge: hasAutoRecordCandidates,
                            onModeSwitch: {
                                hasSwitchedToRecordMode = true
                                modeManager.setMode(.record)
                            },
                            onMyListTabFrame: { myListTabFrame = $0 },
                            onCourseTabFrame: { courseTabFrame = $0 },
                            onRecordButtonFrame: { recordButtonFrame = $0 },
                            onModeSwitchButtonFrame: { modeSwitchButtonFrame = $0 },
                            // コーチマークが表示されている間だけ光らせる（× で閉じた後は静止させる）
                            pulseRecordButton: !isCoachmarkDismissed && !hasCompletedFirstRecord,
                            pulseModeSwitch: !isCoachmarkDismissed && hasCompletedFirstRecord && !hasSwitchedToRecordMode
                        )
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            // 飛翔アニメーション用のルートフレーム取得（.global→ローカル変換用）
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

            // ガイド付きツアー: コーチマーク吹き出し（自前実装。ボタン直上に確実に表示する）
            if !isCoachmarkDismissed, !hasCompletedFirstRecord, recordButtonFrame != .zero {
                CoachmarkOverlay(
                    title: L.Coachmark.recordButtonTitle,
                    message: L.Coachmark.recordButtonMessage,
                    anchorFrame: recordButtonFrame,
                    containerFrame: CGRect(origin: .zero, size: rootSize),
                    placement: .above,
                    onDismiss: { isCoachmarkDismissed = true }
                )
            } else if !isCoachmarkDismissed, hasCompletedFirstRecord, !hasSwitchedToRecordMode, modeSwitchButtonFrame != .zero {
                CoachmarkOverlay(
                    title: L.Coachmark.modeSwitchTitle,
                    message: L.Coachmark.modeSwitchMessage,
                    anchorFrame: modeSwitchButtonFrame,
                    containerFrame: CGRect(origin: .zero, size: rootSize),
                    placement: .above,
                    onDismiss: { isCoachmarkDismissed = true }
                )
            }
        }
        .coordinateSpace(name: "pilgrimageCoachmark")
        .animation(.snappy, value: ui.isTabBarHidden)
        .recordingOverlay(recording)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onReceive(NotificationCenter.default.publisher(for: .courseEnabled)) { notification in
            guard let _ = notification.object as? UUID else { return }
            triggerCourseEnabledEffect()
        }
        .onReceive(NotificationCenter.default.publisher(for: .courseDownloaded)) { _ in
            withAnimation(.spring(duration: 0.4)) { showCourseTabBadge = true }
        }
        .onAppear {
            // RootViewが両モードを常駐させているため、これはモード切り替えのたびではなく
            // アプリ起動時に一度だけ発火する
            refreshAutoRecordCandidateBadge()
            // 起動時に未視認の新着コースがあればバッジを表示
            if courseStore.hasUnseenCourses {
                showCourseTabBadge = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .autoRecordCandidatesChanged)) { _ in
            Task { @MainActor in
                refreshAutoRecordCandidateBadge()
            }
        }
        .onChange(of: recording.confirmationSheetVisitId) { oldValue, newValue in
            // ガイド付きツアー①: 記録直後の確認シートが閉じたタイミングで完了とみなす
            // （.visitsChangedの時点ではシートがまだ開いており、コーチマークが重なってしまうため）
            guard oldValue != nil, newValue == nil, !hasCompletedFirstRecord else { return }
            hasCompletedFirstRecord = true
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

    private func refreshAutoRecordCandidateBadge() {
        do {
            hasAutoRecordCandidates = try AppContainer.shared.candidateRepo.countPending() > 0
        } catch {
            hasAutoRecordCandidates = false
            Logger.error("自動記録候補の件数取得に失敗しました", error: error)
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
    let showRecordModeBadge: Bool
    let onModeSwitch: () -> Void
    let onMyListTabFrame: (CGRect) -> Void
    let onCourseTabFrame: (CGRect) -> Void
    let onRecordButtonFrame: (CGRect) -> Void
    let onModeSwitchButtonFrame: (CGRect) -> Void
    /// ガイド付きツアー①: 記録ボタンをパルス発光させるか
    let pulseRecordButton: Bool
    /// ガイド付きツアー②: モード切替ボタンをパルス発光させるか
    let pulseModeSwitch: Bool
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
                // ガイド付きツアー①: 初回のみパルス発光 + 「現在地を記録してみよう」
                KokokitaTabActionButton(
                    imageName: "kokokita_irodori_indigo_v2",
                    tintColor: colorScheme == .dark ? Color(red: 0.74, green: 0.70, blue: 1.0) : Color.indigo,
                    action: onRecord
                )
                .pulsingHighlight(isActive: pulseRecordButton)
                .reportFrame(in: .named("pilgrimageCoachmark"), onRecordButtonFrame)

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
                // ガイド付きツアー②: 初回記録完了後のみパルス発光 + 「記録を確認しよう」
                Button {
                    onModeSwitch()
                } label: {
                    ZStack(alignment: .topTrailing) {
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

                        if showRecordModeBadge {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 9, height: 9)
                                .offset(x: -6, y: 6)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
                .buttonStyle(.plain)
                .pulsingHighlight(isActive: pulseModeSwitch)
                .reportFrame(in: .named("pilgrimageCoachmark"), onModeSwitchButtonFrame)
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
