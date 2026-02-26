import SwiftUI
import CoreLocation

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
    @State private var showLocationPermissionAlert = false
    @State private var showLocationLoading = false
    @State private var promptSheetLocationData: LocationData?
    @State private var createScreenData: CreateScreenData?
    @State private var confirmationSheetVisitId: UUID?
    @State private var editVisitId: UUID?
    @State private var detailVisitId: UUID?
    @State private var locationErrorMessage: String? = nil
    @State private var showManualEntrySheet = false
    @Environment(AppUIState.self) private var ui
    #if DEBUG
    @ObservedObject private var debugSettings = DebugSettings.shared
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
                        checkLocationPermissionAndCreate()
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

                // 記録画面のみ: 右下にココキタボタン＋追加ボタン（地図シート・カレンダー表示中は非表示）
                if tab == .records && !ui.isMapSheetVisible && !ui.isCalendarVisible {
                    HStack(alignment: .bottom, spacing: 8) {
                        // 後付け記録ボタン
                        FloatingAtozukeButton {
                            showManualEntrySheet = true
                        }

                        // ココキタキタボタン
                        FloatingKokokitaButton {
                            checkLocationPermissionAndCreate()
                        }
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
                            checkLocationPermissionAndCreate()
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

        // ローディング画面（画面中央にオーバーレイ表示）
        .overlay {
            if showLocationLoading {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    VStack(spacing: 24) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))

                        VStack(spacing: 8) {
                            Text(L.Location.acquiringLocation)
                                .font(.headline)

                            Text(L.Location.pleaseWait)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(.systemBackground))
                            .shadow(radius: 20)
                    )
                    .padding(40)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: showLocationLoading)
            }
        }

        // PostKokokitaConfirmationSheet（保存後の確認シート）
        .sheet(isPresented: Binding(
            get: { confirmationSheetVisitId != nil },
            set: { if !$0 { confirmationSheetVisitId = nil } }
        ), onDismiss: {
            // シートが閉じた時にレビュー誘導をチェック
            AppReviewService.shared.onRecordSheetDismissed()
        }) {
            if let visitId = confirmationSheetVisitId {
                PostKokokitaConfirmationSheet(
                    visitId: visitId,
                    onEnterInfo: { id in
                        confirmationSheetVisitId = nil
                        editVisitId = id
                    },
                    onViewDetail: { id in
                        confirmationSheetVisitId = nil
                        detailVisitId = id
                    },
                    onDelete: { id in
                        deleteVisit(id: id)
                    }
                )
                .iPadSheetSize()
            }
        }

        // 新規作成モーダル
        .sheet(item: $createScreenData, onDismiss: {
            NotificationCenter.default.post(name: .visitsChanged, object: nil)
        }) { screenData in
            VisitFormScreen(initialLocationData: screenData.locationData, shouldOpenPOI: screenData.shouldOpenPOI)
                .iPadSheetSize()
                .ignoresSafeArea(.keyboard, edges: .bottom)
        }

        // 編集モーダル
        .sheet(isPresented: Binding(
            get: { editVisitId != nil },
            set: { if !$0 { editVisitId = nil } }
        ), onDismiss: {
            NotificationCenter.default.post(name: .visitsChanged, object: nil)
        }) {
            if let visitId = editVisitId {
                EditVisitSheet(visitId: visitId)
                    .iPadSheetSize()
                    .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }

        // 詳細画面モーダル
        .sheet(isPresented: Binding(
            get: { detailVisitId != nil },
            set: { if !$0 { detailVisitId = nil } }
        )) {
            if let visitId = detailVisitId {
                DetailVisitSheet(visitId: visitId)
                    .iPadSheetSize()
            }
        }

        // 後付け記録モーダル
        .sheet(isPresented: $showManualEntrySheet, onDismiss: {
            NotificationCenter.default.post(name: .visitsChanged, object: nil)
            AppReviewService.shared.onRecordSheetDismissed()
        }) {
            ManualEntryScreen()
                .iPadSheetSize()
        }

        // 位置情報権限アラート
        .alert(L.Location.permissionRequired, isPresented: $showLocationPermissionAlert) {
            Button(L.Location.openSettings) {
                openSettings()
            }
            Button(L.Common.cancel, role: .cancel) {}
        } message: {
            Text(L.Location.permissionMessage)
        }

        // 位置情報取得エラーアラート
        .alert(L.Location.acquisitionFailed, isPresented: Binding(
            get: { locationErrorMessage != nil },
            set: { if !$0 { locationErrorMessage = nil } }
        )) {
            Button(L.Common.ok, role: .cancel) {
                locationErrorMessage = nil
            }
        } message: {
            Text(locationErrorMessage ?? "")
        }
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

    // MARK: - Helper Methods

    private func checkLocationPermissionAndCreate() {
        let locationManager = CLLocationManager()
        let status = locationManager.authorizationStatus

        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            // 権限あり：位置情報を取得
            Task {
                await fetchLocationAndShowPrompt()
            }
        case .notDetermined:
            // 未決定：システムダイアログが表示されるので位置情報取得を試みる
            Task {
                await fetchLocationAndShowPrompt()
            }
        case .denied, .restricted:
            // 拒否済み：設定誘導アラートを表示
            showLocationPermissionAlert = true
        @unknown default:
            // 未知のステータス：念のため位置情報取得を試みる
            Task {
                await fetchLocationAndShowPrompt()
            }
        }
    }

    @MainActor
    private func fetchLocationAndShowPrompt() async {
        // ローディング表示
        showLocationLoading = true

        do {
            let locationService = LocationGeocodingService(
                locationService: AppContainer.shared.loc
            )

            // 低精度で素早く取得（1秒未満）
            let quickResult = try await locationService.requestQuickLocation { _ in }

            let quickData = LocationData(
                timestamp: quickResult.timestamp,
                latitude: quickResult.latitude,
                longitude: quickResult.longitude,
                accuracy: quickResult.accuracy,
                address: quickResult.address,
                flags: quickResult.flags
            )

            // すぐに保存してconfirmationSheetを表示（素早いフィードバック）
            if let savedId = quickSaveLocation(quickData) {
                showLocationLoading = false
                confirmationSheetVisitId = savedId

                // バックグラウンドで高精度取得して更新
                Task {
                    await refineLocationAndUpdate(
                        savedId: savedId,
                        locationService: locationService,
                        quickData: quickData
                    )
                }
            } else {
                showLocationLoading = false
                locationErrorMessage = L.Error.saveFailed
            }

        } catch {
            showLocationLoading = false

            // エラーの種類に応じて処理
            if case LocationServiceError.permissionDenied = error {
                // 位置情報の権限が拒否された場合
                showLocationPermissionAlert = true
            } else {
                // その他のエラー（タイムアウト、シミュレート検出など）
                Logger.error("Location acquisition failed", error: error)

                // ユーザーにエラーを表示
                let errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                locationErrorMessage = errorMessage
            }
        }
    }

    @MainActor
    private func refineLocationAndUpdate(
        savedId: UUID,
        locationService: LocationGeocodingService,
        quickData: LocationData
    ) async {
        do {
            let refinedResult = try await locationService.refineLocation { _ in }

            // 高精度の結果で更新
            let repo = AppContainer.shared.repo
            try repo.updateDetails(id: savedId) { details in
                details.resolvedAddress = refinedResult.address ?? quickData.address
            }

            // Visitの位置情報も更新（デバッグモードのみ）
            #if DEBUG
            let integ = AppContainer.shared.integ
            let newIntegrity = try integ.signImmutablePayload(
                id: savedId,
                timestampUTC: quickData.timestamp,
                lat: refinedResult.latitude,
                lon: refinedResult.longitude,
                acc: refinedResult.accuracy,
                flags: refinedResult.flags,
                createdAtUTC: quickData.timestamp
            )
            try repo.updateVisitTimestamp(id: savedId, newTimestamp: quickData.timestamp, newIntegrity: newIntegrity)
            #endif

            Logger.info("Location refined to higher accuracy: \(refinedResult.accuracy ?? 0)m")
            NotificationCenter.default.post(name: .visitsChanged, object: nil)
        } catch {
            // 高精度取得失敗しても低精度の結果があるので問題なし
            Logger.warning("Failed to refine location, using quick result: \(error.localizedDescription)")
        }
    }

    @discardableResult
    private func quickSaveLocation(_ data: LocationData) -> UUID? {
        let repo = AppContainer.shared.repo
        let integ = AppContainer.shared.integ

        do {
            let id = UUID()
            let integrity = try integ.signImmutablePayload(
                id: id,
                timestampUTC: data.timestamp,
                lat: data.latitude,
                lon: data.longitude,
                acc: data.accuracy,
                flags: data.flags
            )

            let visit = Visit(
                id: id,
                timestampUTC: data.timestamp,
                latitude: data.latitude,
                longitude: data.longitude,
                horizontalAccuracy: data.accuracy,
                isSimulatedBySoftware: data.flags.isSimulatedBySoftware,
                isProducedByAccessory: data.flags.isProducedByAccessory,
                integrity: integrity
            )

            let details = VisitDetails(
                title: nil,
                facilityName: nil,
                facilityAddress: nil,
                facilityCategory: nil,
                comment: nil,
                labelIds: [],
                groupId: nil,
                memberIds: [],
                resolvedAddress: data.address,
                photoPaths: []
            )

            try repo.create(visit: visit, details: details)
            NotificationCenter.default.post(name: .visitsChanged, object: nil)

            // レビュー誘導用：記録数をカウント
            AppReviewService.shared.recordCreated()

            return id
        } catch {
            Logger.error("Quick save failed", error: error)
            return nil
        }
    }

    private func deleteVisit(id: UUID) {
        let repo = AppContainer.shared.repo
        do {
            try repo.delete(id: id)
            NotificationCenter.default.post(name: .visitsChanged, object: nil)
        } catch {
            Logger.error("Failed to delete visit", error: error)
            locationErrorMessage = L.Error.deleteFailed
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

private struct CustomBottomBar: View {
    let current: RootTab
    let onSelect: (RootTab) -> Void
    let onCenterTap: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .frame(height: UIConstants.Size.tabBarHeight)
                .overlay(Divider(), alignment: .top)

            // 全ての画面で4タブのスライディングタブバーに統一
            HomeTabBar(current: current, onSelect: onSelect)
        }
    }
}

// MARK: - Home Tab Bar (4タブ、スライディングインジケーター)

fileprivate struct HomeTabBar: View {
    let current: RootTab
    let onSelect: (RootTab) -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 固定背景コンテナ
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.12),
                                        Color.white.opacity(0.04)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 3)

                // タブ定義（ここで追加・削除すれば自動的に均等配置される）
                let tabItems: [(icon: String, title: String, tab: RootTab)] = [
                    ("house.fill", L.Tab.home, .home),
                    ("list.bullet", L.Tab.records, .records),
                    // ("map", L.Tab.course, .course),  // リリース後に復活予定
                    ("ellipsis.circle.fill", L.Tab.menu, .menu),
                ]
                let tabCount = CGFloat(tabItems.count)
                let tabWidth = (geometry.size.width - 16) / tabCount
                let currentIndex = tabItems.firstIndex(where: { $0.tab == current }) ?? 0

                // スライディングインジケーター (ヌルッと移動)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.accentColor.opacity(0.15),
                                        Color.accentColor.opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.accentColor.opacity(0.3),
                                        Color.accentColor.opacity(0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .frame(width: tabWidth, height: geometry.size.height - 12)
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                    .offset(x: 6 + CGFloat(currentIndex) * tabWidth)
                    .animation(.interpolatingSpring(stiffness: 150, damping: 18), value: current)

                // ボタンラベル
                HStack(spacing: 0) {
                    ForEach(Array(tabItems.enumerated()), id: \.offset) { _, item in
                        tabButton(icon: item.icon, title: item.title, tab: item.tab, width: tabWidth)
                    }
                }
                .padding(6)
            }
        }
        .frame(height: 64)
        .padding(.horizontal, UIConstants.Spacing.extraLarge + 8)
        .padding(.bottom, UIConstants.Spacing.medium)
    }

    private func tabButton(icon: String, title: String, tab: RootTab, width: CGFloat) -> some View {
        Button {
            onSelect(tab)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                    .fontWeight(current == tab ? .semibold : .regular)
                Text(title)
                    .font(.caption2)
                    .fontWeight(current == tab ? .semibold : .regular)
            }
            .foregroundStyle(current == tab ? Color.accentColor : Color.primary.opacity(0.5))
            .frame(width: width)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Others Tab Bar (4タブ + 中央ボタン、スライディングインジケーター)

fileprivate struct OthersTabBar: View {
    let current: RootTab
    let onSelect: (RootTab) -> Void
    let onCenterTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 左側の2タブグループ
            leftTabGroup

            Spacer()

            // 中央: ココキタボタン
            centerButton

            Spacer()

            // 右側の2タブグループ
            rightTabGroup
        }
        .padding(.horizontal, UIConstants.Spacing.extraLarge + 8)
        .padding(.bottom, UIConstants.Spacing.medium)
    }

    // 左側タブグループ (Home, Records)
    private var leftTabGroup: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 固定背景コンテナ
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.12),
                                        Color.white.opacity(0.04)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 3)

                // スライディングインジケーター
                let tabWidth = (geometry.size.width - 12) / 2
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.accentColor.opacity(0.15),
                                        Color.accentColor.opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.accentColor.opacity(0.3),
                                        Color.accentColor.opacity(0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .frame(width: tabWidth, height: geometry.size.height - 12)
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                    .offset(x: current == .home ? 6 : tabWidth + 6)
                    .animation(.interpolatingSpring(stiffness: 150, damping: 18), value: current)

                // ボタンラベル
                HStack(spacing: 0) {
                    tabButton(icon: "house.fill", title: L.Tab.home, tab: .home, width: tabWidth)
                    tabButton(icon: "list.bullet", title: L.Tab.records, tab: .records, width: tabWidth)
                }
                .padding(6)
            }
        }
        .frame(width: 160, height: 64)
    }

    // 右側タブグループ (Course, Menu)
    private var rightTabGroup: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 固定背景コンテナ
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.12),
                                        Color.white.opacity(0.04)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 3)

                // スライディングインジケーター
                let tabWidth = (geometry.size.width - 12) / 2
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.accentColor.opacity(0.15),
                                        Color.accentColor.opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.accentColor.opacity(0.3),
                                        Color.accentColor.opacity(0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .frame(width: tabWidth, height: geometry.size.height - 12)
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                    .offset(x: 6)
                    .animation(.interpolatingSpring(stiffness: 150, damping: 18), value: current)

                // ボタンラベル
                HStack(spacing: 0) {
                    tabButton(icon: "ellipsis.circle.fill", title: L.Tab.menu, tab: .menu, width: tabWidth)
                }
                .padding(6)
            }
        }
        .frame(width: 160, height: 64)
    }

    private var centerButton: some View {
        Button(action: onCenterTap) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.95),
                                Color.accentColor.opacity(0.75)
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
                    .frame(width: UIConstants.Size.centerButtonSize,
                           height: UIConstants.Size.centerButtonSize)
                    .shadow(color: Color.accentColor.opacity(0.35), radius: 8, x: 0, y: 2)
                    .shadow(color: Color.accentColor.opacity(0.15), radius: 3, x: 0, y: 1)

                VStack(spacing: 0) {
                    Image("kokokita_irodori_white")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 42, height: 42)
                        .accessibilityHidden(true)
                    Text(L.App.name)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .offset(y: -2)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
            }
            .padding(.horizontal, UIConstants.Spacing.medium - 2)
        }
        .accessibilityLabel(L.Tab.kokokita)
    }

    private func tabButton(icon: String, title: String, tab: RootTab, width: CGFloat) -> some View {
        Button {
            onSelect(tab)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                    .fontWeight(current == tab ? .semibold : .regular)
                Text(title)
                    .font(.caption2)
                    .fontWeight(current == tab ? .semibold : .regular)
            }
            .foregroundStyle(current == tab ? Color.accentColor : Color.primary.opacity(0.5))
            .frame(width: width)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Floating Kokokita Button (右下固定配置)

fileprivate struct FloatingKokokitaButton: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.95),
                                Color.accentColor.opacity(0.75)
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
                    .shadow(color: Color.accentColor.opacity(0.35), radius: 12, x: 0, y: 4)
                    .shadow(color: Color.accentColor.opacity(0.15), radius: 6, x: 0, y: 2)

                VStack(spacing: 2) {
                    Image("kokokita_irodori_white")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                    Text(L.App.name)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L.Tab.kokokita)
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
                    .frame(width: 44, height: 44)
                    .shadow(color: Color.orange.opacity(0.32), radius: 8, x: 0, y: 3)
                    .shadow(color: Color.orange.opacity(0.12), radius: 4, x: 0, y: 2)

                VStack(spacing: 2) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("＋追加")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L.ManualEntry.addManualEntry)
    }
}

// MARK: - Edit Visit Sheet

private struct EditVisitSheet: View {
    let visitId: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var visit: VisitAggregate?

    var body: some View {
        Group {
            if let visit = visit {
                EditView(aggregate: visit) {
                    dismiss()
                }
            } else {
                ProgressView()
                    .task {
                        await loadVisit()
                    }
            }
        }
    }

    @MainActor
    private func loadVisit() async {
        let repo = AppContainer.shared.repo
        do {
            self.visit = try repo.get(by: visitId)
        } catch {
            Logger.error("Failed to load visit for editing", error: error)
        }
    }
}

// MARK: - Detail Visit Sheet

private struct DetailVisitSheet: View {
    let visitId: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(AppUIState.self) private var ui
    @State private var visit: VisitAggregate?
    @State private var labelMap: [UUID: String] = [:]
    @State private var groupMap: [UUID: String] = [:]
    @State private var memberMap: [UUID: String] = [:]

    var body: some View {
        Group {
            if let visit = visit {
                NavigationStack {
                    VisitDetailScreen(
                        data: toDetailData(visit),
                        visitId: visitId,
                        onBack: {},
                        onEdit: {},
                        onShare: {},
                        onDelete: {
                            deleteVisit()
                            dismiss()
                        },
                        onUpdate: {},
                        onMapTap: {
                            dismiss()
                            ui.mapFocusVisitId = visitId
                        }
                    )
                }
            } else {
                ProgressView()
                    .task {
                        await loadVisit()
                    }
            }
        }
    }

    @MainActor
    private func loadVisit() async {
        let repo = AppContainer.shared.repo
        do {
            self.visit = try repo.get(by: visitId)

            // タクソノミーのマップを取得
            let labels = try repo.allLabels()
            let groups = try repo.allGroups()
            let members = try repo.allMembers()

            labelMap = Dictionary(uniqueKeysWithValues: labels.map { ($0.id, $0.name) })
            groupMap = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0.name) })
            memberMap = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0.name) })
        } catch {
            Logger.error("Failed to load visit for detail", error: error)
        }
    }

    private func toDetailData(_ agg: VisitAggregate) -> VisitDetailData {
        let title: String = {
            let t = agg.details.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let t, !t.isEmpty { return t }
            if let f = agg.details.facilityName, !f.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return f }
            return L.Home.noTitle
        }()

        let labels: [String] = agg.details.labelIds.compactMap { labelMap[$0] }
        let group: String? = agg.details.groupId.flatMap { groupMap[$0] }
        let members: [String] = agg.details.memberIds.compactMap { memberMap[$0] }

        let coord: CLLocationCoordinate2D? = {
            let lat = agg.visit.latitude
            let lon = agg.visit.longitude
            if lat == 0 && lon == 0 { return nil }
            return .init(latitude: lat, longitude: lon)
        }()

        let address = agg.details.resolvedAddress ?? agg.details.facilityAddress

        return VisitDetailData(
            title: title,
            labels: labels,
            group: group,
            members: members,
            timestamp: agg.visit.timestampUTC,
            address: address,
            coordinate: coord,
            memo: agg.details.comment,
            facility: FacilityInfo(
                name: agg.details.facilityName,
                address: agg.details.facilityAddress,
                phone: nil
            ),
            facilityCategory: agg.details.facilityCategory,
            photoPaths: agg.details.photoPaths,
            isManualEntry: agg.visit.isManualEntry
        )
    }

    private func deleteVisit() {
        let repo = AppContainer.shared.repo
        do {
            try repo.delete(id: visitId)
            NotificationCenter.default.post(name: .visitsChanged, object: nil)
        } catch {
            Logger.error("Failed to delete visit from detail sheet", error: error)
        }
    }
}

private var bannerAdUnitID: String {
    #if DEBUG
    return "ca-app-pub-3940256099942544/2934735716"
    #else
    return "ca-app-pub-7495977536865069/2544041585"
    #endif
}
