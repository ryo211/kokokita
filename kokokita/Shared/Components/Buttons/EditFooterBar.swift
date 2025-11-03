import SwiftUI

/// 編集画面の下部固定ボタンバー
struct EditFooterBar: View {
    var onSave: () -> Void
    var onPoi: () -> Void
    var saveDisabled: Bool

    var body: some View {
        // TabBarやホームインジケータを避けつつ、上に固定表示される
        HStack(spacing: UIConstants.Spacing.large) {
            // 保存（プライマリ）
            Button {
                onSave()
            } label: {
                HStack(spacing: UIConstants.Spacing.medium) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(L.Common.save)
                }
                .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(BorderedProminentButtonStyle())
            .controlSize(.large)
            .buttonBorderShape(.roundedRectangle(radius: UIConstants.CornerRadius.medium + 2))
            .disabled(saveDisabled)

            // ココカモ？
            Button {
                onPoi()
            } label: {
                HStack(spacing: UIConstants.Spacing.medium) {
                    Image(systemName: "magnifyingglass.circle.fill")
                    Text(L.VisitEdit.kokokamo)
                }
                .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(BorderedButtonStyle())
            .controlSize(.large)
            .buttonBorderShape(.roundedRectangle(radius: UIConstants.CornerRadius.medium + 2))
        }
        .padding(.horizontal, UIConstants.Padding.screenHorizontal)
        .padding(.top, UIConstants.Spacing.medium)
        .padding(.bottom, UIConstants.Spacing.medium) // 安全地帯上での余白
        .background(.regularMaterial) // 半透明で上に敷く
    }
}
