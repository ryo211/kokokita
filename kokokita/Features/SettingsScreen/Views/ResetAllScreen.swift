import SwiftUI

struct ResetAllScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showConfirm = false
    @State private var alert: String?

    // 開発者向けデータ移行機能
    @State private var showPasswordSheet = false
    @State private var showDataMigrationScreen = false
    @State private var longPressTimer: Timer?
    @State private var longPressDuration: Double = 0.0
    private let longPressThreshold: Double = 5.0 // 5秒

    var body: some View {
        Form {
            Section {
                Button(role: .destructive) {
                    showConfirm = true
                } label: {
                    Label(L.Settings.deleteAllButton, systemImage: "trash")
                }
            } footer: {
                Text(L.Settings.resetMessage)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                // タイトルを長押しで隠し機能にアクセス
                Text(L.Settings.resetTitle)
                    .font(.headline)
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: longPressThreshold, pressing: { isPressing in
                        if isPressing {
                            startLongPress()
                        } else {
                            cancelLongPress()
                        }
                    }, perform: {
                        longPressSucceeded()
                    })
            }
        }
        .alert(L.Settings.resetConfirmTitle, isPresented: $showConfirm) {
            Button(L.Common.cancel, role: .cancel) {}
            Button(L.Common.delete, role: .destructive) { performReset() }
        } message: {
            Text(L.Settings.resetConfirmMessage)
        }
        .alert(L.Common.error, isPresented: Binding(get: { alert != nil }, set: { _ in alert = nil })) {
            Button(L.Common.ok, role: .cancel) {}
        } message: { Text(alert ?? "") }
        .sheet(isPresented: $showPasswordSheet) {
            DeveloperPasswordSheet(onAuthenticated: {
                showPasswordSheet = false
                showDataMigrationScreen = true
            })
        }
        .sheet(isPresented: $showDataMigrationScreen) {
            DataMigrationScreen()
        }
    }

    // MARK: - Long Press Logic

    private func startLongPress() {
        guard longPressTimer == nil else { return }

        longPressDuration = 0.0
        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            longPressDuration += 0.1
            // 進行状況表示のみ（10秒の判定はonLongPressGestureのperformで行う）
        }
    }

    private func cancelLongPress() {
        longPressTimer?.invalidate()
        longPressTimer = nil
        longPressDuration = 0.0
    }

    private func longPressSucceeded() {
        // タイマーをクリーンアップ
        longPressTimer?.invalidate()
        longPressTimer = nil
        longPressDuration = 0.0

        // 長押し成功：パスワードシートを表示
        showPasswordSheet = true
    }

    // MARK: - Reset Logic

    private func performReset() {
        do {
            try AppContainer.shared.repo.deleteAllVisits()
            NotificationCenter.default.post(name: .visitsChanged, object: nil)
            dismiss()
        } catch {
            alert = error.localizedDescription
        }
    }
}
