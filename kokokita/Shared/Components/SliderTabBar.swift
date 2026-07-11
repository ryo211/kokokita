import SwiftUI

// スライダータブバーの各タブ定義
struct SliderTabBarItem<Tab: Hashable>: Identifiable {
    let id: Tab
    let icon: String
    let title: String
    var showBadge: Bool = false
}

// 汎用スライダータブバー（RootTab / PilgrimageTab どちらでも使える）
// HomeTabBar から抽出した共通コンポーネント
struct SliderTabBar<Tab: Hashable>: View {
    let items: [SliderTabBarItem<Tab>]
    let current: Tab
    let onSelect: (Tab) -> Void
    var tintColor: Color = .accentColor
    @Environment(\.colorScheme) private var colorScheme

    private var containerOverlay: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color(.secondarySystemBackground).opacity(0.86),
                    Color(.tertiarySystemBackground).opacity(0.68)
                ]
                : [
                    Color.white.opacity(0.12),
                    Color.white.opacity(0.04)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var containerBorder: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color.white.opacity(0.16),
                    Color.white.opacity(0.05)
                ]
                : [
                    Color.white.opacity(0.2),
                    Color.white.opacity(0.08)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var indicatorFill: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    tintColor.opacity(0.34),
                    tintColor.opacity(0.18)
                ]
                : [
                    tintColor.opacity(0.15),
                    tintColor.opacity(0.08)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var indicatorBorder: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    tintColor.opacity(0.62),
                    tintColor.opacity(0.26)
                ]
                : [
                    tintColor.opacity(0.3),
                    tintColor.opacity(0.15)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var indicatorHighlight: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color.white.opacity(0.14),
                    Color.clear
                ]
                : [
                    Color.white.opacity(0.2),
                    Color.clear
                ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var inactiveForeground: Color {
        colorScheme == .dark ? Color.primary.opacity(0.64) : Color.primary.opacity(0.5)
    }

    private var selectedForeground: Color {
        colorScheme == .dark ? tintColor.opacity(0.96) : tintColor
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 固定背景コンテナ
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(colorScheme == .dark ? .regularMaterial : .ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(containerOverlay)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(
                                containerBorder,
                                lineWidth: 0.5
                            )
                    }
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.32 : 0.1), radius: 8, x: 0, y: 3)

                let tabCount = max(CGFloat(items.count), 1)
                let tabWidth = max((geometry.size.width - 16) / tabCount, 0)
                let currentIndex = items.firstIndex(where: { $0.id == current }) ?? 0

                // スライディングインジケーター（ヌルッと移動）
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(colorScheme == .dark ? .thinMaterial : .ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(indicatorFill)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(indicatorHighlight)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                indicatorBorder,
                                lineWidth: 1
                            )
                    }
                    .frame(width: tabWidth, height: max(geometry.size.height - 12, 0))
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.24 : 0.08), radius: 6, x: 0, y: 2)
                    .offset(x: 6 + CGFloat(currentIndex) * tabWidth)
                    .animation(.interpolatingSpring(stiffness: 150, damping: 18), value: current)

                // ボタンラベル
                HStack(spacing: 0) {
                    ForEach(items) { item in
                        tabButton(item: item, width: tabWidth)
                    }
                }
                .padding(6)
            }
        }
        .frame(height: 64)
    }

    private func tabButton(item: SliderTabBarItem<Tab>, width: CGFloat) -> some View {
        Button {
            onSelect(item.id)
        } label: {
            ZStack {
                VStack(spacing: 3) {
                    Image(systemName: item.icon)
                        .font(.title3)
                        .fontWeight(current == item.id ? .semibold : .regular)
                    Text(item.title)
                        .font(.caption2)
                        .fontWeight(current == item.id ? .semibold : .regular)
                }
                .foregroundStyle(current == item.id ? selectedForeground : inactiveForeground)
                .frame(width: width)
                .contentShape(Rectangle())

                if item.showBadge {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .offset(x: 10, y: -12)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct KokokitaTabActionButton: View {
    let imageName: String
    let tintColor: Color
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var backgroundFill: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    tintColor.opacity(0.22),
                    Color(.secondarySystemBackground).opacity(0.94)
                ]
                : [
                    Color.white.opacity(0.72),
                    tintColor.opacity(0.08)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    tintColor.opacity(0.58),
                    Color.white.opacity(0.10)
                ]
                : [
                    tintColor.opacity(0.34),
                    Color.white.opacity(0.70)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .shadow(color: tintColor.opacity(colorScheme == .dark ? 0.24 : 0.12), radius: 3, x: 0, y: 1)

                Text(L.Tab.kokokita)
                    .font(.system(size: 9, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(colorScheme == .dark ? tintColor.opacity(0.96) : tintColor.opacity(0.86))
            }
            .frame(width: 58, height: 58)
            .background {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(colorScheme == .dark ? .thinMaterial : .ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .fill(backgroundFill)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .strokeBorder(borderGradient, lineWidth: 1)
                    }
            }
            .shadow(
                color: colorScheme == .dark ? Color.black.opacity(0.28) : tintColor.opacity(0.16),
                radius: colorScheme == .dark ? 7 : 5,
                x: 0,
                y: 2
            )
            .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L.Tab.kokokita)
    }
}
