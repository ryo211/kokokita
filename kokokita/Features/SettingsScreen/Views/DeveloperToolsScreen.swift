import SwiftUI
import FirebaseCrashlytics

#if DEBUG
struct DeveloperToolsScreen: View {
    @State private var showCrashAlert = false
    @ObservedObject private var debugSettings = DebugSettings.shared

    var body: some View {
        List {
            Section {
                NavigationLink {
                    DataMigrationScreen()
                } label: {
                    Label(L.Settings.dataMigration, systemImage: "arrow.up.arrow.down.circle")
                        .foregroundStyle(.blue)
                }
            }

            Section {
                Toggle(isOn: $debugSettings.isAdDisplayEnabled) {
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
        // Crashlyticsのテストクラッシュを発生させる
        Crashlytics.crashlytics().log("テストクラッシュを実行します")
        fatalError("Test Crash for Firebase Crashlytics")
    }
}
#endif
