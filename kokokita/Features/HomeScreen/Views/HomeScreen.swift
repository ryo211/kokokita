import SwiftUI

struct HomeScreen: View {
    @Environment(AppUIState.self) private var ui
    @State private var showSettings = false
    @State private var showBookDrawer = false
    @State private var store = VisitListStore(repo: AppContainer.shared.repo)
    @State private var isPulsing = true
    @State private var recentVisits: [VisitAggregate]? = nil  // nilで初期化
    @State private var hasStartedAnimation = false
    @State private var pendingCandidateCount: Int = 0
    @State private var showAutoRecordReview = false
    @State private var autoRecordEffects = AutoRecordToggleEffects()
    @ObservedObject private var autoRecordSettings = AutoRecordSettings.shared
    /// ガイド付きツアー②完了（記録モードへの遷移）。PilgrimageRootTabViewと@AppStorageで共有する
    @AppStorage("coachmark.hasSwitchedToRecordMode") private var hasSwitchedToRecordMode = false
    /// コーチマークを閉じる（×）操作で二度と表示しないようにするフラグ。他画面とも共有する
    @AppStorage("coachmark.dismissed") private var isCoachmarkDismissed = false
    /// 自動記録ON/OFFボタンのフレーム（"homeCoachmark"座標空間、コーチマーク位置計算用）
    @State private var autoRecordButtonFrame: CGRect = .zero
    /// このビュー自身のサイズ（"homeCoachmark"座標空間の原点は常に(0,0)なので、サイズだけ分かればよい）
    @State private var homeRootSize: CGSize = .zero

    let onKokokitaTap: () -> Void
    let onViewAllTap: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                // サイズ測定用（ZStackの直接の子として置くことで、確実にZStack自身のサイズを取得する。
                // .background(GeometryReader{...})による自己測定は.coordinateSpace(name:)のスコープと
                // 噛み合わないことがあり、原点が(0,0)にならないバグの原因になっていた）
                GeometryReader { geo in
                    Color.clear
                        .onAppear { homeRootSize = geo.size }
                        .onChange(of: geo.size) { _, newSize in homeRootSize = newSize }
                }

                // 背景（グラデーション + 抽象ライン装飾。記録リスト等とも共有）
                HomeStyleBackground()

                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        // 自動記録候補バナー（控えめな導線）
                        if pendingCandidateCount > 0 {
                            autoRecordPendingBanner
                        }

                        // 自動記録ON/OFFボタン（トグル代わりの行。ツールバーだとGeometryReaderで
                        // 正確な位置が測れずコーチマークがずれるため、本編コンテンツ内に配置する）
                        autoRecordToggleRow
                    }
                    .padding(.top, 8)

                    Spacer()

                    // メイン: 大きなKokokitaボタン
                    kokokitaButton

                    Spacer()

                    // 最近の記録セクション（高さ固定でボタンのジャンプを防止）
                    Group {
                        if let visits = recentVisits {
                            if !visits.isEmpty {
                                recentRecordsSection
                            } else {
                                emptyRecordsPlaceholder
                            }
                        } else {
                            Color.clear
                        }
                    }
                    .frame(height: 150)
                }
                // ZStackのデフォルト中央揃えのままだと、広告バナー表示分で高さが足りない時に
                // 上（ツールバー側）・下（広告側）の両方向へ均等にはみ出して隠れてしまっていた。
                // 上端基準に固定し、はみ出しが起きても下方向のみになるようにする
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.bottom, 24)

                // ガイド付きツアー③: 自動記録ON/OFFボタンのコーチマーク（自前実装。ボタン直下に確実に表示する）
                if !isCoachmarkDismissed, hasSwitchedToRecordMode, !autoRecordSettings.isEnabled, autoRecordButtonFrame != .zero {
                    CoachmarkOverlay(
                        title: L.Coachmark.autoRecordToggleTitle,
                        message: L.Coachmark.autoRecordToggleMessage,
                        anchorFrame: autoRecordButtonFrame,
                        containerFrame: CGRect(origin: .zero, size: homeRootSize),
                        placement: .below,
                        onDismiss: { isCoachmarkDismissed = true }
                    )
                }
            }
            .coordinateSpace(name: "homeCoachmark")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showBookDrawer = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "book.closed.fill")
                                .font(.subheadline)
                                .foregroundStyle(ui.currentBook?.color ?? Color(.systemBlue))
                            Text(ui.currentBook?.name ?? L.Book.myBook)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showSettings) {
                SettingsSheet()
            }
            .sheet(isPresented: $showAutoRecordReview) {
                AutoRecordCandidateReviewScreen()
                    .onDisappear { loadPendingCandidateCount() }
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
            .overlay(alignment: .leading) {
                if showBookDrawer {
                    BookPickerDrawer(onDismiss: { withAnimation(.easeInOut(duration: 0.2)) { showBookDrawer = false } })
                        .transition(.move(edge: .leading))
                }
            }
            .animation(.easeInOut(duration: 0.22), value: showBookDrawer)
        }
        .task {
            // アニメーション開始（初回のみ）
            if !hasStartedAnimation {
                hasStartedAnimation = true
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isPulsing.toggle()
                }
            }
        }
        .onAppear {
            // 画面表示のたびに最新データを読み込む
            loadTaxonomy()
            loadRecentVisits()
            loadPendingCandidateCount()
        }
        .onReceive(NotificationCenter.default.publisher(for: .visitsChanged)) { _ in
            loadTaxonomy()
            loadRecentVisits()
            loadPendingCandidateCount()
        }
        .onReceive(NotificationCenter.default.publisher(for: .bookChanged)) { _ in
            ui.currentBook = AppContainer.shared.currentBook
            loadTaxonomy()
            loadRecentVisits()
        }
    }

    // MARK: - Auto Record Pending Banner

    private var autoRecordPendingBanner: some View {
        Button {
            showAutoRecordReview = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .font(.subheadline)
                Text(L.AutoRecord.homePendingBanner(pendingCandidateCount))
                    .font(.subheadline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.accentColor.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Auto Record Toggle Row

    private var autoRecordToggleRow: some View {
        Button {
            if autoRecordSettings.isEnabled {
                autoRecordEffects.handleToggleOff()
            } else {
                autoRecordEffects.handleToggleOn()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .font(.subheadline)
                Text(autoRecordSettings.isEnabled ? L.AutoRecord.homeToggleOnLabel : L.AutoRecord.homeToggleOffLabel)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Image(systemName: autoRecordSettings.isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(autoRecordSettings.isEnabled ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(autoRecordSettings.isEnabled ? Color.accentColor.opacity(0.85) : Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        // コーチマークが表示されている間だけ光らせる（× で閉じた後は静止させる）
        .pulsingHighlight(isActive: !isCoachmarkDismissed && hasSwitchedToRecordMode && !autoRecordSettings.isEnabled)
        .reportFrame(in: .named("homeCoachmark")) { autoRecordButtonFrame = $0 }
    }

    // MARK: - Kokokita Button

    private var kokokitaButton: some View {
        Button {
            onKokokitaTap()
        } label: {
            VStack(spacing: 48) {
                // Liquid Glass円形ボタン
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.accentColor.opacity(0.2),
                                            Color.accentColor.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.accentColor.opacity(0.4),
                                            Color.accentColor.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        }
                        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
                        .shadow(color: Color.accentColor.opacity(0.3), radius: 30, x: 0, y: 15)  // 一時的に固定値

                    Image("kokokita_irodori_blue")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                }
                .frame(width: 140, height: 140)
                 .scaleEffect(isPulsing ? 1.08 : 1.0, anchor: .center)

                // ラベル（固定）
                Text(L.NewHome.recordLocation)
                    .font(.headline)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.9),
                                Color.accentColor.opacity(0.7)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recent Records Section

    private var recentRecordsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L.NewHome.recentRecords)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    onViewAllTap()
                } label: {
                    Text(L.NewHome.viewAllRecords)
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 32)
//            .padding(.bottom, 4)

            RecentRecordsCarousel(
                records: recentRecords,
                labelMap: store.labels.nameMap,
                groupMap: store.groups.nameMap,
                memberMap: store.members.nameMap,
                labelColorMap: store.labels.colorMap,
                onUpdate: {
                    loadRecentVisits()
                }
            )
        }
    }

    private var emptyRecordsPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
                .opacity(0.5)
            Text(L.NewHome.noRecentRecords)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 40)
    }

    // MARK: - Helpers

    private var recentRecords: [VisitAggregate] {
        recentVisits ?? []
    }

    /// タクソノミー（ラベル・グループ・メンバー）のみ軽量に読み込み
    private func loadTaxonomy() {
        do {
            store.labels = try AppContainer.shared.repo.allLabels()
            store.groups = try AppContainer.shared.repo.allGroups()
            store.members = try AppContainer.shared.repo.allMembers()
        } catch {
            Logger.error("Failed to load taxonomy: \(error.localizedDescription)")
        }
    }

    /// 自動記録の未確認候補数を取得
    private func loadPendingCandidateCount() {
        do {
            pendingCandidateCount = try AppContainer.shared.candidateRepo.countPending()
        } catch {
            Logger.error("Failed to load pending candidate count: \(error.localizedDescription)")
        }
    }

    /// 最新5件のみを Core Data レベルで取得
    private func loadRecentVisits() {
        do {
            let newRecents = try AppContainer.shared.repo.fetchRecent(limit: 5)
            withAnimation {
                recentVisits = newRecents
            }
        } catch {
            Logger.error("Failed to load recent visits: \(error.localizedDescription)")
            withAnimation {
                recentVisits = []
            }
        }
    }
}

