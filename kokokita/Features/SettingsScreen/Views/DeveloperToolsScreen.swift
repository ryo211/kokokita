import SwiftUI
import FirebaseCrashlytics

#if DEBUG
struct DeveloperToolsScreen: View {
    @State private var showCrashAlert = false
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

            // MARK: - プレミアム状態のデバッグ制御
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
                Picker("プレミアムオーバーライド", selection: Binding(
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
}
#endif
