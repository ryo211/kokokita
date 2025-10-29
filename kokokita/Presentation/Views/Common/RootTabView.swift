//
//  RootTabView.swift
//  kokokita
//
//  Created by 橋本遼 on 2025/09/22.
//

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
    @EnvironmentObject private var ui: AppUIState

    var body: some View {
        // ← 重ねずに“占有する”縦積みレイアウトに変更
        VStack(spacing: 0) {
            // ===== コンテンツ領域（フッター分を除いた残り全体） =====
            ZStack { // （必要なければ Group でもOK）
                switch tab {
                case .home:
                    NavigationStack { HomeView() }

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
                    NavigationStack { MenuHomeView() }

                case .center:
                    Color.clear // 中央ボタンは別途 sheet 起動
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ===== フッター領域（バナー + カスタムタブバー） =====
            VStack(spacing: 0) {
                // 固定バナー（フッターの“上”に配置）
                BannerAdView(adUnitID: bannerAdUnitID)
                    .background(.thinMaterial)
                    .transition(.opacity)

                if !ui.isTabBarHidden {
                    CustomBottomBar(
                        current: tab,
                        onSelect: { tab = $0 },
                        onCenterTap: {
                            checkLocationPermissionAndCreate()
                        }
                    )
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
                            Text("位置情報を取得中...")
                                .font(.headline)

                            Text("しばらくお待ちください")
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

        // PostKokokitaPromptSheet
        .sheet(item: $promptSheetLocationData) { data in
            PostKokokitaPromptSheet(
                locationData: data,
                onQuickSave: {
                    // 即保存
                    quickSaveLocation(data)
                    promptSheetLocationData = nil
                },
                onOpenEditor: {
                    // 編集画面を開く
                    promptSheetLocationData = nil
                    createScreenData = CreateScreenData(locationData: data, shouldOpenPOI: false)
                },
                onOpenPOI: {
                    // ココカモを開く
                    promptSheetLocationData = nil
                    createScreenData = CreateScreenData(locationData: data, shouldOpenPOI: true)
                },
                onCancel: {
                    promptSheetLocationData = nil
                }
            )
            .presentationDetents([.large])
        }

        // 新規作成モーダル
        .sheet(item: $createScreenData, onDismiss: {
            NotificationCenter.default.post(name: .visitsChanged, object: nil)
        }) { screenData in
            CreateView(initialLocationData: screenData.locationData, shouldOpenPOI: screenData.shouldOpenPOI)
                .presentationDetents([.large])
                .ignoresSafeArea(.keyboard, edges: .bottom)
        }

        // 位置情報権限アラート
        .alert("位置情報の権限が必要です", isPresented: $showLocationPermissionAlert) {
            Button("設定を開く") {
                openSettings()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("位置情報を使用するには、設定アプリで位置情報の使用を許可してください。")
        }
    }

    // MARK: - Helper Methods

    private func checkLocationPermissionAndCreate() {
        let status = CLLocationManager.authorizationStatus()

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

            let result = try await locationService.requestLocationWithAddress { address in
                // バックグラウンドで住所が取得できた時
                Task { @MainActor in
                    if var data = self.promptSheetLocationData {
                        self.promptSheetLocationData = LocationData(
                            timestamp: data.timestamp,
                            latitude: data.latitude,
                            longitude: data.longitude,
                            accuracy: data.accuracy,
                            address: address,
                            flags: data.flags
                        )
                    }
                }
            }

            let data = LocationData(
                timestamp: result.timestamp,
                latitude: result.latitude,
                longitude: result.longitude,
                accuracy: result.accuracy,
                address: result.address,
                flags: result.flags
            )

            // ローディング閉じてPromptSheet表示
            showLocationLoading = false
            promptSheetLocationData = data

        } catch {
            showLocationLoading = false
            // エラー時は権限アラート表示
            if case LocationServiceError.permissionDenied = error {
                showLocationPermissionAlert = true
            }
        }
    }

    private func quickSaveLocation(_ data: LocationData) {
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
        } catch {
            print("Quick save failed: \(error)")
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
                            Text("ココキタ")
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

private var bannerAdUnitID: String {
    #if DEBUG
    return "ca-app-pub-3940256099942544/2934735716"
    #else
    return "ca-app-pub-xxxxxxxxxxxxxxxx/zzzzzzzzzz"
    #endif
}
