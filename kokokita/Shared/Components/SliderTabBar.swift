import SwiftUI

// スライダータブバーの各タブ定義
struct SliderTabBarItem<Tab: Hashable>: Identifiable {
    let id: Tab
    let icon: String
    let title: String
}

// 汎用スライダータブバー（RootTab / PilgrimageTab どちらでも使える）
// HomeTabBar から抽出した共通コンポーネント
struct SliderTabBar<Tab: Hashable>: View {
    let items: [SliderTabBarItem<Tab>]
    let current: Tab
    let onSelect: (Tab) -> Void
    var tintColor: Color = .accentColor

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 固定背景コンテナ
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.12),
                                        Color.white.opacity(0.04)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
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
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 3)

                let tabCount = max(CGFloat(items.count), 1)
                let tabWidth = max((geometry.size.width - 16) / tabCount, 0)
                let currentIndex = items.firstIndex(where: { $0.id == current }) ?? 0

                // スライディングインジケーター（ヌルッと移動）
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        tintColor.opacity(0.15),
                                        tintColor.opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        tintColor.opacity(0.3),
                                        tintColor.opacity(0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .frame(width: tabWidth, height: max(geometry.size.height - 12, 0))
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                    .offset(x: 6 + CGFloat(currentIndex) * tabWidth)
                    .animation(.interpolatingSpring(stiffness: 150, damping: 18), value: current)

                // ボタンラベル
                HStack(spacing: 0) {
                    ForEach(items) { item in
                        tabButton(icon: item.icon, title: item.title, tab: item.id, width: tabWidth)
                    }
                }
                .padding(6)
            }
        }
        .frame(height: 64)
    }

    private func tabButton(icon: String, title: String, tab: Tab, width: CGFloat) -> some View {
        Button {
            onSelect(tab)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.title3)
                    .fontWeight(current == tab ? .semibold : .regular)
                Text(title)
                    .font(.caption2)
                    .fontWeight(current == tab ? .semibold : .regular)
            }
            .foregroundStyle(current == tab ? tintColor : Color.primary.opacity(0.5))
            .frame(width: width)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
