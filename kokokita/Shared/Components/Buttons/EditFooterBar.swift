import SwiftUI

/// 編集画面の下部固定ボタンバー
struct EditFooterBar: View {
    var onSave: () -> Void
    var onPoi: () -> Void
    var saveDisabled: Bool

    var body: some View {
        // TabBarやホームインジケータを避けつつ、上に固定表示される
        HStack(spacing: UIConstants.Spacing.large) {
            // 保存ボタン（Liquid Glass プライマリ）
            Button {
                onSave()
            } label: {
                HStack(spacing: UIConstants.Spacing.medium) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                    Text(L.Common.save)
                        .font(.body.bold())
                }
                .foregroundStyle(saveDisabled ? Color.white.opacity(0.5) : Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: saveDisabled ? [
                                        Color.gray.opacity(0.6),
                                        Color.gray.opacity(0.4)
                                    ] : [
                                        Color.accentColor.opacity(0.95),
                                        Color.accentColor.opacity(0.75)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.25),
                                                Color.clear
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }
                            .shadow(
                                color: saveDisabled ? Color.black.opacity(0.15) : Color.accentColor.opacity(0.35),
                                radius: 8, x: 0, y: 2
                            )
                            .shadow(
                                color: saveDisabled ? Color.black.opacity(0.05) : Color.accentColor.opacity(0.15),
                                radius: 3, x: 0, y: 1
                            )
                    }
                )
            }
            .buttonStyle(.plain)
            .disabled(saveDisabled)

            // ココカモボタン（Liquid Glass セカンダリ）
            Button {
                onPoi()
            } label: {
                HStack(spacing: UIConstants.Spacing.medium) {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.body)
                    Text(L.VisitEdit.kokokamo)
                        .font(.body)
                }
                .foregroundStyle(Color.primary.opacity(0.75))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.12),
                                                Color.white.opacity(0.03)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.2),
                                                Color.white.opacity(0.08)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.5
                                    )
                            }
                            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                    }
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, UIConstants.Padding.screenHorizontal)
        .padding(.top, UIConstants.Spacing.medium)
        .padding(.bottom, UIConstants.Spacing.medium) // 安全地帯上での余白
        .background(
            // 背景もLiquid Glass化
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.05),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                Divider()
                    .frame(maxWidth: .infinity, alignment: .top)
            }
        )
    }
}
