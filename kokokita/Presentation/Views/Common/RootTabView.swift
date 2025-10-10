//
//  RootTabView.swift
//  kokokita
//
//  Created by 橋本遼 on 2025/09/22.
//

import SwiftUI

enum RootTab: Hashable {
    case home, /* map, */ center, /* calendar, */ menu
}

struct RootTabView: View {
    @State private var tab: RootTab = .home
    @State private var showCreate = false
    @EnvironmentObject private var ui: AppUIState

    var body: some View {
        // ← 重ねずに“占有する”縦積みレイアウトに変更
        VStack(spacing: 0) {
            // ===== コンテンツ領域（フッター分を除いた残り全体） =====
            ZStack { // （必要なければ Group でもOK）
                switch tab {
                case .home:
                    NavigationStack { HomeView() }

                // case .map:
                //     NavigationStack {
                //         VStack(spacing: 12) {
                //             Image(systemName: "map").font(.largeTitle)
                //             Text("地図（後日実装）").foregroundStyle(.secondary)
                //         }
                //         .navigationTitle("地図")
                //         .navigationBarTitleDisplayMode(.inline)
                //     }

                // case .calendar:
                //     NavigationStack {
                //         VStack(spacing: 12) {
                //             Image(systemName: "calendar").font(.largeTitle)
                //             Text("カレンダー（後日実装）").foregroundStyle(.secondary)
                //         }
                //         .navigationTitle("カレンダー")
                //         .navigationBarTitleDisplayMode(.inline)
                //     }

                case .menu:
                    NavigationStack { MenuHomeView() }

                case .center:
                    Color.clear // 中央ボタンは別途 sheet 起動
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ===== フッター領域（バナー + カスタムタブバー） =====
            VStack(spacing: 0) {
                // 固定バナー（フッターの“上”に配置）
                BannerAdView(adUnitID: bannerAdUnitID)
                    .background(.thinMaterial)
                    .transition(.opacity)

                if !ui.isTabBarHidden {
                    CustomBottomBar(
                        current: tab,
                        onSelect: { tab = $0 },
                        onCenterTap: { showCreate = true }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            // ここまでが“常に表示される固定領域”
        }
        // 画面全体の背景（下は Safe Area を無視しない）
        .background(Color(.systemBackground))
        .animation(.snappy, value: ui.isTabBarHidden)
        // キーボードだけ下端を無視（入力用画面で下が切れないように）
        .ignoresSafeArea(.keyboard, edges: .bottom)

        // 新規作成モーダル
        .sheet(isPresented: $showCreate, onDismiss: {
            NotificationCenter.default.post(name: .visitsChanged, object: nil)
        }) {
            CreateView()
                .presentationDetents([.large])
                .ignoresSafeArea(.keyboard, edges: .bottom)
        }
    }
}

private struct CustomBottomBar: View {
    let current: RootTab
    let onSelect: (RootTab) -> Void
    let onCenterTap: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .frame(height: 72)
                .overlay(Divider(), alignment: .top)

            HStack {
                barButton(icon: "house.fill", title: "ホーム", tab: .home)
                // barButton(icon: "map.fill", title: "地図", tab: .map)

                Button(action: onCenterTap) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 64, height: 64)
                            .shadow(radius: 6, y: 2)
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(.white)
                            .font(.title2.weight(.semibold))
                    }
                    .padding(.horizontal, 6)
                }
                .accessibilityLabel("ココキタ")

                // barButton(icon: "calendar", title: "カレンダー", tab: .calendar)
                barButton(icon: "ellipsis.circle.fill", title: "メニュー", tab: .menu)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
    }

    private func barButton(icon: String, title: String, tab: RootTab) -> some View {
        Button {
            onSelect(tab)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.title3)
                Text(title).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(current == tab ? .primary : .secondary)
        }
        .buttonStyle(.plain)
    }
}

private var bannerAdUnitID: String {
    #if DEBUG
    return "ca-app-pub-3940256099942544/2934735716"
    #else
    return "ca-app-pub-xxxxxxxxxxxxxxxx/zzzzzzzzzz"
    #endif
}
