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
                    Label("ラベルを編集", systemImage: "tag")
                }

                NavigationLink {
                    GroupListScreen()
                } label: {
                    Label("グループを編集", systemImage: "folder")
                }

                NavigationLink {
                    MemberListScreen()
                } label: {
                    Label("メンバーを編集", systemImage: "person")
                }
            }

            #if DEBUG
            Section {
                Button {
                    testErrorLogging()
                } label: {
                    Label("エラーログをテスト", systemImage: "ladybug")
                        .foregroundStyle(.orange)
                }

                Button {
                    showCrashAlert = true
                } label: {
                    Label("クラッシュをテスト", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
                .alert("テストクラッシュ", isPresented: $showCrashAlert) {
                    Button("キャンセル", role: .cancel) { }
                    Button("実行", role: .destructive) {
                        testCrash()
                    }
                } message: {
                    Text("アプリが強制終了します。Firebase Crashlyticsで確認できます。")
                }
            } header: {
                Text("開発者向けテスト")
            }
            #endif

            Section {
                NavigationLink {
                    ResetAllScreen()
                } label: {
                    Label("初期化（全削除）", systemImage: "trash")
                        .foregroundStyle(.red)
                }
            } footer: {
                Text("「初期化」は全ての記録を削除します。元に戻せません。")
            }
        }
        .navigationTitle("メニュー")
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

