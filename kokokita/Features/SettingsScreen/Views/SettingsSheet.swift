import SwiftUI

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModeManager.self) private var modeManager
    @ObservedObject private var autoRecordSettings = AutoRecordSettings.shared
    @State private var showCandidateReview = false
    @State private var pendingCandidateCount: Int = 0

    var body: some View {
        NavigationStack {
            List {
                // 自動記録
                Section {
                    Toggle(isOn: $autoRecordSettings.isEnabled) {
                        Label(L.AutoRecord.settingsToggle, systemImage: "waveform.path.ecg")
                    }
                    .onChange(of: autoRecordSettings.isEnabled) { _, isEnabled in
                        if isEnabled {
                            AppContainer.shared.autoRecord.requestAlwaysAuthorization()
                            AppContainer.shared.autoRecord.startMonitoring()
                        } else {
                            AppContainer.shared.autoRecord.stopMonitoring()
                        }
                    }

                    if autoRecordSettings.isEnabled {
                        Button {
                            showCandidateReview = true
                        } label: {
                            HStack {
                                Label(L.AutoRecord.reviewCandidates, systemImage: "list.bullet.clipboard")
                                    .foregroundStyle(.primary)
                                Spacer()
                                if pendingCandidateCount > 0 {
                                    Text("\(pendingCandidateCount)")
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(Color.accentColor)
                                        .clipShape(Capsule())
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text(L.AutoRecord.settingsTitle)
                } footer: {
                    Text(L.AutoRecord.settingsToggleDescription)
                }

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

                    Link(destination: URL(string: "https://apps.apple.com/app/id6755731775?action=write-review")!) {
                        Label(L.SettingsSheet.reviewApp, systemImage: "star.bubble")
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
            .sheet(isPresented: $showCandidateReview) {
                AutoRecordCandidateReviewScreen()
                    .onDisappear { loadPendingCount() }
            }
            .onAppear { loadPendingCount() }
        }
    }

    private func loadPendingCount() {
        pendingCandidateCount = (try? AppContainer.shared.candidateRepo.countPending()) ?? 0
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }
}
