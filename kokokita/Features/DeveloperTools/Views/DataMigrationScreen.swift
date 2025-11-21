import SwiftUI
import UniformTypeIdentifiers

/// 開発者向けデータ移行画面
struct DataMigrationScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isBackupInProgress = false
    @State private var isRestoreInProgress = false
    @State private var backupResult: BackupResult?
    @State private var showShareSheet = false
    @State private var showFilePicker = false
    @State private var alert: AlertMessage?

    private let repo = AppContainer.shared.repo

    var body: some View {
        NavigationStack {
            List {
                // バックアップセクション
                Section {
                    Button {
                        performBackup()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title3)
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L.DataMigration.backupSection)
                                    .font(.headline)
                                Text(L.DataMigration.backupDescription)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if isBackupInProgress {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isBackupInProgress || isRestoreInProgress)
                } header: {
                    Text(L.DataMigration.backupButton)
                } footer: {
                    Text("訪問記録、写真、ラベル、グループ等の全データをエクスポートします。")
                }

                // リストアセクション
                Section {
                    Button {
                        checkAndRestore()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .font(.title3)
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L.DataMigration.restoreSection)
                                    .font(.headline)
                                Text("ZIPファイルからデータを復元")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if isRestoreInProgress {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isBackupInProgress || isRestoreInProgress)
                } header: {
                    Text(L.DataMigration.restoreButton)
                } footer: {
                    Text("⚠️ データが1件もない状態でのみ使用できます。既存データは全て削除されます。")
                        .foregroundColor(.orange)
                }

                // 結果表示セクション
                if let result = backupResult {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(L.DataMigration.backupCompleteTitle)
                                    .font(.headline)
                            }

                            Text("\(L.DataMigration.backupFilename): \(result.filename)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)

                            Text("\(L.DataMigration.backupSize): \(ByteCountFormatter.string(fromByteCount: result.fileSize, countStyle: .file))")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("記録数: \(result.visitCount)件")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button {
                                showShareSheet = true
                            } label: {
                                Label(L.DataMigration.shareFile, systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .padding(.top, 8)
                        }
                    } header: {
                        Text(L.DataMigration.backupResultTitle)
                    }
                }
            }
            .navigationTitle(L.DataMigration.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.Common.close) {
                        dismiss()
                    }
                }
            }
            .alert(item: $alert) { alertMsg in
                Alert(
                    title: Text(alertMsg.title),
                    message: Text(alertMsg.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: $showShareSheet) {
                if let result = backupResult {
                    ShareSheet(items: [result.fileURL])
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.zip],
                onCompletion: { result in
                    handleFileSelection(result)
                }
            )
        }
    }

    // MARK: - Backup

    private func performBackup() {
        isBackupInProgress = true
        backupResult = nil

        Task {
            do {
                let service = DataBackupService(repo: repo)
                let result = try await service.createBackup()
                await MainActor.run {
                    backupResult = result
                    isBackupInProgress = false
                }
            } catch {
                await MainActor.run {
                    alert = AlertMessage(
                        title: L.DataMigration.backupErrorTitle,
                        message: error.localizedDescription
                    )
                    isBackupInProgress = false
                }
            }
        }
    }

    // MARK: - Restore

    private func checkAndRestore() {
        // データが空かチェック
        do {
            let count = try repo.allVisitsCount()
            if count > 0 {
                alert = AlertMessage(
                    title: L.DataMigration.restoreNotPossibleTitle,
                    message: L.DataMigration.restoreNotPossibleMessage
                )
                return
            }

            // 空なのでファイルピッカーを表示
            showFilePicker = true
        } catch {
            alert = AlertMessage(
                title: L.Common.error,
                message: error.localizedDescription
            )
        }
    }

    private func handleFileSelection(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            performRestore(from: url)
        case .failure(let error):
            alert = AlertMessage(
                title: L.DataMigration.fileSelectError,
                message: error.localizedDescription
            )
        }
    }

    private func performRestore(from url: URL) {
        isRestoreInProgress = true

        Task {
            do {
                let service = DataRestoreService(repo: repo)
                try await service.restore(from: url)

                await MainActor.run {
                    alert = AlertMessage(
                        title: L.DataMigration.restoreCompleteTitle,
                        message: L.DataMigration.restoreCompleteMessage
                    )
                    isRestoreInProgress = false
                }
            } catch {
                await MainActor.run {
                    alert = AlertMessage(
                        title: L.DataMigration.restoreErrorTitle,
                        message: error.localizedDescription
                    )
                    isRestoreInProgress = false
                }
            }
        }
    }
}

// MARK: - Supporting Types

struct BackupResult {
    let filename: String
    let fileURL: URL
    let fileSize: Int64
    let visitCount: Int
}

struct AlertMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
