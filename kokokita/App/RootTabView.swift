import SwiftUI
import CoreLocation

enum RootTab: Hashable {
    case home, /* map, */ center, /* calendar, */ menu
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
    @State private var locationErrorMessage: String? = nil
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
            ZStack { // （必要なければ Group でもOK）
                switch tab {
                case .home:
                    NavigationStack { VisitListScreen() }

                // case .map:
                //     NavigationStack {
                //         VStack(spacing: 12) {
                //             Image(systemName: "map").font(.largeTitle)
                //             Text("地図（後日実装）").foregroundStyle(.secondary)
                //         }
                //         .navigationTitle("地図")
                //         .navigationBarTitleDisplayMode(.inline)
                //     }

                // case .calendar:
                //     NavigationStack {
                //         VStack(spacing: 12) {
                //             Image(systemName: "calendar").font(.largeTitle)
                //             Text("カレンダー（後日実装）").foregroundStyle(.secondary)
                //         }
                //         .navigationTitle("カレンダー")
                //         .navigationBarTitleDisplayMode(.inline)
                //     }

                case .menu:
                    NavigationStack { SettingsHomeScreen() }

                case .center:
                    Color.clear // 中央ボタンは別途 sheet 起動
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
        )) {
            if let visitId = confirmationSheetVisitId {
                PostKokokitaConfirmationSheet(
                    visitId: visitId,
                    onEnterInfo: { id in
                        confirmationSheetVisitId = nil
                        editVisitId = id
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

            HStack {
                barButton(icon: "house.fill", title: L.Tab.home, tab: .home)
                // barButton(icon: "map.fill", title: "地図", tab: .map)

                Button(action: onCenterTap) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: UIConstants.Size.centerButtonSize,
                                   height: UIConstants.Size.centerButtonSize)
                            .shadow(radius: UIConstants.Shadow.radiusMedium * 3, y: UIConstants.Shadow.radiusMedium)

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

                // barButton(icon: "calendar", title: "カレンダー", tab: .calendar)
                barButton(icon: "ellipsis.circle.fill", title: L.Tab.menu, tab: .menu)
            }
            .padding(.horizontal, UIConstants.Spacing.extraLarge + 8)
            .padding(.bottom, UIConstants.Spacing.medium)
        }
    }

    private func barButton(icon: String, title: String, tab: RootTab) -> some View {
        Button {
            onSelect(tab)
        } label: {
            VStack(spacing: UIConstants.Spacing.small) {
                Image(systemName: icon).font(.title3)
                Text(title).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(current == tab ? .primary : .secondary)
        }
        .buttonStyle(.plain)
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

private var bannerAdUnitID: String {
    #if DEBUG
    return "ca-app-pub-3940256099942544/2934735716"
    #else
    return "ca-app-pub-7495977536865069/2544041585"
    #endif
}
