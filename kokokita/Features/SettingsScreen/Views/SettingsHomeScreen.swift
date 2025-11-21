import SwiftUI
import FirebaseCrashlytics

struct SettingsHomeScreen: View {
    @State private var showCrashAlert = false

    var body: some View {
        List {
            Section {
                NavigationLink {
                    LabelListScreen()
                } label: {
                    Label(L.Settings.editLabels, systemImage: "tag")
                }

                NavigationLink {
                    GroupListScreen()
                } label: {
                    Label(L.Settings.editGroups, systemImage: "folder")
                }

                NavigationLink {
                    MemberListScreen()
                } label: {
                    Label(L.Settings.editMembers, systemImage: "person")
                }
            }

            #if DEBUG
            Section {
                NavigationLink {
                    DataMigrationScreen()
                } label: {
                    Label(L.Settings.dataMigration, systemImage: "arrow.up.arrow.down.circle")
                        .foregroundStyle(.blue)
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
            #endif

            Section {
                NavigationLink {
                    ResetAllScreen()
                } label: {
                    Label(L.Settings.resetAll, systemImage: "trash")
                        .foregroundStyle(.red)
                }
            } footer: {
                Text(L.Settings.resetAllDescription)
            }
        }
        .navigationTitle(L.Settings.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Test Functions

    #if DEBUG
    private func testErrorLogging() {
        Logger.error("テストエラー：これはFirebase Crashlyticsのテストです")
        Logger.warning("テスト警告：非致命的なエラーのテストです")
    }

    private func testCrash() {
        // Crashlyticsのテストクラッシュを発生させる
        Crashlytics.crashlytics().log("テストクラッシュを実行します")
        fatalError("Test Crash for Firebase Crashlytics")
    }
    #endif
}

