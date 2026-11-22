import SwiftUI
import FirebaseCrashlytics

#if DEBUG
struct DeveloperToolsScreen: View {
    @State private var showCrashAlert = false
    @State private var spotArrivalResetMessage: String?
    @State private var courseEventResetMessage: String?
    private var debugSettings = DebugSettings.shared
    private var premiumManager = PremiumManager.shared

    var body: some View {
        List {
            Section {
                NavigationLink {
                    DataMigrationScreen()
                } label: {
                    Label(L.Settings.dataMigration, systemImage: "arrow.up.arrow.down.circle")
                        .foregroundStyle(.blue)
                }

                NavigationLink {
                    AppIconGeneratorScreen()
                } label: {
                    Label("App Icon Generator", systemImage: "app.dashed")
                        .foregroundStyle(.indigo)
                }

                NavigationLink {
                    AppStoreScreenshotBackgroundGenerator()
                } label: {
                    Label("Screenshot Background", systemImage: "photo.stack")
                        .foregroundStyle(.pink)
                }
            }

            Section {
                @Bindable var bindableSettings = debugSettings
                Toggle(isOn: $bindableSettings.isAdDisplayEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(L.Settings.adDisplay, systemImage: "rectangle.inset.filled.and.person.filled")
                        Text(L.Settings.adDisplayDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    testErrorLogging()
                } label: {
                    Label(L.Settings.testErrorLog, systemImage: "ladybug")
                        .foregroundStyle(.orange)
                }

                Button {
                    showCrashAlert = true
                } label: {
                    Label(L.Settings.testCrash, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
                .alert(L.Settings.testCrashTitle, isPresented: $showCrashAlert) {
                    Button(L.Common.cancel, role: .cancel) { }
                    Button(L.DataMigration.execute, role: .destructive) {
                        testCrash()
                    }
                } message: {
                    Text(L.Settings.testCrashMessage)
                }
            } header: {
                Text(L.Settings.developerTest)
            }

            // MARK: - 到達記録送信デバッグ
            Section {
                Button {
                    resetSpotArrivalSentFlags()
                } label: {
                    Label("到達記録の送信済みフラグをリセット", systemImage: "arrow.counterclockwise.circle")
                        .foregroundStyle(.teal)
                }
                if let message = spotArrivalResetMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("到達記録デバッグ")
            } footer: {
                Text("サーバー側のテストデータ（spot_arrivals等）を手動で削除した後、端末側の送信済み判定をリセットして再送信可能にする。")
                    .font(.caption)
            }

            // MARK: - コースイベント（閲覧・お気に入り）送信デバッグ
            Section {
                Button {
                    resetCourseEvents()
                } label: {
                    Label("コースイベント（閲覧・お気に入り）の記録を全削除", systemImage: "arrow.counterclockwise.circle")
                        .foregroundStyle(.teal)
                }
                if let message = courseEventResetMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("コースイベントデバッグ")
            } footer: {
                Text("「1日1回まで」のローカル重複防止チェックのため、サーバー側のcourse_eventsを手動で削除しただけでは同日中は再送信されない。ここで端末側の記録も削除すれば再テストできる。")
                    .font(.caption)
            }

            // MARK: - Premium状態のデバッグ制御
            Section {
                // 現在の状態表示
                HStack {
                    Label(
                        premiumManager.isPremium ? L.Paywall.alreadyPremium : "フリー",
                        systemImage: premiumManager.isPremium ? "crown.fill" : "crown"
                    )
                    .foregroundStyle(premiumManager.isPremium ? .orange : .secondary)
                    Spacer()
                    if premiumManager.debugOverride != nil {
                        Text("強制中")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.orange)
                            .clipShape(Capsule())
                    }
                }

                // オーバーライドの3択ピッカー
                Picker("Premiumオーバーライド", selection: Binding(
                    get: {
                        switch premiumManager.debugOverride {
                        case .none:  return 0
                        case true:   return 1
                        case false:  return 2
                        default:     return 0
                        }
                    },
                    set: { value in
                        switch value {
                        case 1:  premiumManager.debugOverride = true
                        case 2:  premiumManager.debugOverride = false
                        default: premiumManager.debugOverride = nil
                        }
                    }
                )) {
                    Text(L.Paywall.debugOverrideNone).tag(0)
                    Text(L.Paywall.debugOverrideOn).tag(1)
                    Text(L.Paywall.debugOverrideOff).tag(2)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            } header: {
                Text("課金デバッグ")
            } footer: {
                Text("アプリを再起動しても設定は保持されます。")
                    .font(.caption)
            }
        }
        .navigationTitle(L.Settings.developerTest)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Test Functions

    private func testErrorLogging() {
        Logger.error("テストエラー：これはFirebase Crashlyticsのテストです")
        Logger.warning("テスト警告：非致命的なエラーのテストです")
    }

    private func testCrash() {
        Crashlytics.crashlytics().log("テストクラッシュを実行します")
        fatalError("Test Crash for Firebase Crashlytics")
    }

    private func resetSpotArrivalSentFlags() {
        do {
            try AppContainer.shared.spotArrivalOutboxRepo.resetAllSentFlagsForDebug()
            spotArrivalResetMessage = "リセットしました。再起動またはフォアグラウンド復帰で再送信されます。"
            Task {
                await AppContainer.shared.spotArrivalSyncService.flushPending()
            }
        } catch {
            spotArrivalResetMessage = "リセットに失敗しました: \(error.localizedDescription)"
        }
    }

    private func resetCourseEvents() {
        do {
            try AppContainer.shared.courseEventOutboxRepo.deleteAllForDebug()
            courseEventResetMessage = "削除しました。再度コース詳細を開く・お気に入り追加すると記録されます。"
        } catch {
            courseEventResetMessage = "削除に失敗しました: \(error.localizedDescription)"
        }
    }
}
#endif
