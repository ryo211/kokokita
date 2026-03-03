import SwiftUI

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var modeManager: AppModeManager

    var body: some View {
        NavigationStack {
            List {
                // アプリモード切替
                Section {
                    Button {
                        let newMode: AppMode = modeManager.mode == .record ? .pilgrimage : .record
                        modeManager.setMode(newMode)
                        dismiss()
                    } label: {
                        Label(
                            modeManager.mode == .record
                                ? L.ModeSelection.switchToPilgrimage
                                : L.ModeSelection.switchToRecord,
                            systemImage: modeManager.mode == .record
                                ? "figure.walk"
                                : "mappin.circle.fill"
                        )
                    }
                } header: {
                    Text(L.ModeSelection.appModeSection)
                }

                // 外部リンク
                Section {
                    Link(destination: URL(string: "https://x.com/irodoriq")!) {
                        Label(L.SettingsSheet.followOnX, systemImage: "link")
                    }

                    Link(destination: URL(string: "https://kokokita.irodoriq.com/support/")!) {
                        Label(L.SettingsSheet.support, systemImage: "headphones.circle")
                    }
                }

                // 開発者ツール (DEBUG build only)
                #if DEBUG
                Section(header: Text(L.SettingsSheet.developerTools)) {
                    NavigationLink {
                        DeveloperToolsScreen()
                    } label: {
                        Label("Developer Tools", systemImage: "wrench.and.screwdriver")
                    }
                }
                #endif

                // バージョン情報
                Section {
                    HStack {
                        Text(L.SettingsSheet.version)
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                }

                // リセット
                Section {
                    NavigationLink {
                        ResetAllScreen()
                    } label: {
                        Label(L.SettingsSheet.resetAll, systemImage: "trash.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(L.SettingsSheet.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L.Common.close) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }
}
