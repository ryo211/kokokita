import SwiftUI

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModeManager.self) private var modeManager
    @ObservedObject private var autoRecordSettings = AutoRecordSettings.shared
    @State private var autoRecordEffects = AutoRecordToggleEffects()
    @State private var showCandidateReview = false
    @State private var showExcludedLocations = false
    @State private var pendingCandidateCount: Int = 0
    @State private var showPaywall = false
    private var premiumManager = PremiumManager.shared

    var body: some View {
        NavigationStack {
            List {
                // プレミアム
                premiumSection

                // 自動記録
                Section {
                    Toggle(isOn: $autoRecordSettings.isEnabled) {
                        Label(L.AutoRecord.settingsToggle, systemImage: "waveform.path.ecg")
                    }
                    .onChange(of: autoRecordSettings.isEnabled) { _, isEnabled in
                        // ToggleはisEnabledを直接bindingで更新するが、実際にはAlways許可が
                        // 確定するまで有効化しないため、Effects側の非同期処理の結果次第で
                        // trueにした直後にfalseへ戻ることがある（意図した挙動）
                        if isEnabled {
                            autoRecordEffects.handleToggleOn()
                        } else {
                            autoRecordEffects.handleToggleOff()
                        }
                    }

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

                    NavigationLink {
                        ExcludedLocationsScreen()
                    } label: {
                        Label(L.AutoRecord.excludedLocationsTitle, systemImage: "location.slash")
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
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $autoRecordEffects.showIntroSheet) {
                AutoRecordIntroSheet(onDismiss: { autoRecordEffects.introSheetDismissed() })
            }
            .alert(L.AutoRecord.permissionTitle, isPresented: $autoRecordEffects.showSettingsGuidance) {
                Button(L.AutoRecord.permissionOpenSettings) { autoRecordEffects.openSettings() }
                Button(L.Common.cancel, role: .cancel) {}
            } message: {
                Text(L.AutoRecord.permissionMessage)
            }
            .onAppear { loadPendingCount() }
        }
    }

    // MARK: - Premium Section

    private var premiumSection: some View {
        Section {
            if premiumManager.isPremium {
                // 購入済み：ステータス表示
                HStack(spacing: 12) {
                    Image("kokokita_prp")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.SettingsSheet.premiumActive)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)
                        Text(L.SettingsSheet.premiumActiveDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.orange)
                }
                .padding(.vertical, 4)
            } else {
                // 未購入：アップグレードCTA
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 12) {
                        Image("kokokita_prp")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 44, height: 44)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L.SettingsSheet.premiumUpgrade)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(L.SettingsSheet.premiumUpgradeDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
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
