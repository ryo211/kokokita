import SwiftUI

// 初回起動時に表示するモード選択画面
// ユーザーが「記録モード」または「巡礼モード」を選択する
struct ModeSelectionView: View {
    @EnvironmentObject private var modeManager: AppModeManager

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // ロゴ・タイトル
            VStack(spacing: 16) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.accentColor)

                Text(L.ModeSelection.title)
                    .font(.largeTitle.bold())

                Text(L.ModeSelection.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            // モード選択ボタン
            VStack(spacing: 16) {
                ModeSelectionCard(
                    icon: "figure.walk",
                    title: L.ModeSelection.pilgrimageTitle,
                    description: L.ModeSelection.pilgrimageDescription,
                    color: .indigo
                ) {
                    selectMode(.pilgrimage)
                }

                ModeSelectionCard(
                    icon: "mappin.circle.fill",
                    title: L.ModeSelection.recordTitle,
                    description: L.ModeSelection.recordDescription,
                    color: .accentColor
                ) {
                    selectMode(.record)
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            Text(L.ModeSelection.canChangeInSettings)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 24)
        }
    }

    private func selectMode(_ mode: AppMode) {
        modeManager.setMode(mode)
        modeManager.markModeSelectionSeen()
    }
}

// モード選択カード
private struct ModeSelectionCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(color)
                    .frame(width: 50)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(20)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
