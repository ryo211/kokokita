import SwiftUI

/// CoreDataの読み込みに失敗した際に表示するエラー画面
struct DataErrorView: View {
    @State private var showResetConfirmation = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // エラーアイコン
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.orange)

            // メッセージ
            VStack(spacing: 12) {
                Text("データの読み込みに失敗しました")
                    .font(.title2.bold())

                Text("アプリのデータベースに問題が発生しています。\n以下の対処方法をお試しください。")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Spacer()

            // アクションボタン
            VStack(spacing: 16) {
                // 再起動ボタン
                Button {
                    restartApp()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("アプリを再起動")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }

                // サポート連絡ボタン
                Button {
                    contactSupport()
                } label: {
                    HStack {
                        Image(systemName: "envelope")
                        Text("サポートに連絡")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }

                // データリセットボタン（危険）
                Button {
                    showResetConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("データをリセット")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .alert("データをリセットしますか？", isPresented: $showResetConfirmation) {
                    Button("キャンセル", role: .cancel) { }
                    Button("リセット", role: .destructive) {
                        resetData()
                    }
                } message: {
                    Text("すべての訪問記録が削除されます。この操作は取り消せません。")
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            // 詳細情報（デバッグ用）
            if let error = CoreDataStack.shared.loadError {
                VStack(spacing: 4) {
                    Text("エラー詳細:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 16)
            }
        }
        .padding(.vertical, 32)
    }

    // MARK: - Actions

    private func restartApp() {
        // アプリを終了（ユーザーが手動で再起動する）
        exit(0)
    }

    private func contactSupport() {
        // メールアプリを開く
        let email = "irodori.developer@gmail.com"
        let subject = "データ読み込みエラーの報告"

        var body = "以下のエラーが発生しました：\n\n"
        if let error = CoreDataStack.shared.loadError {
            body += "エラー: \(error.localizedDescription)\n"
            body += "詳細: \(error)\n"
        }
        body += "\niOSバージョン: \(UIDevice.current.systemVersion)\n"
        body += "アプリバージョン: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "不明")"

        let urlString = "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"

        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    private func resetData() {
        // CoreDataストアを削除
        let coordinator = CoreDataStack.shared.container.persistentStoreCoordinator

        for store in coordinator.persistentStores {
            if let storeURL = store.url {
                try? coordinator.remove(store)
                try? FileManager.default.removeItem(at: storeURL)

                // WALファイルとSHMファイルも削除
                let walURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
                let shmURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
                try? FileManager.default.removeItem(at: walURL)
                try? FileManager.default.removeItem(at: shmURL)
            }
        }

        // アプリを再起動
        exit(0)
    }
}
