import SwiftUI

/// 開発者向けデータ移行機能のパスワード認証画面
struct DeveloperPasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var password: String = ""
    @State private var showError = false

    let onAuthenticated: () -> Void

    // パスワード（ハードコード - 開発者向け機能なので許容）
    private let correctPassword = "t4Z7Ee2T"

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)

                    Text("開発者認証")
                        .font(.title2.bold())
                }

                VStack(spacing: 16) {
                    SecureField("パスワード", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .padding(.horizontal, 32)

                    Button {
                        authenticate()
                    } label: {
                        Text("認証")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(password.isEmpty ? Color.gray : Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(password.isEmpty)
                    .padding(.horizontal, 32)
                }

                Spacer()
            }
            .navigationTitle("開発者モード")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
            .alert("認証エラー", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("パスワードが間違っています")
            }
        }
    }

    private func authenticate() {
        if password == correctPassword {
            onAuthenticated()
        } else {
            showError = true
            password = ""
        }
    }
}
