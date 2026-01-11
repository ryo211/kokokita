import SwiftUI
import Foundation
import MapKit

/// 一覧シート：POIの3カテゴリトグルで絞り込み
struct KokokamoPOISheet<Item: Identifiable>: View {
    let items: [Item]

    // 表示用
    let name: (Item) -> String
    let address: (Item) -> String?

    // ★ 重要：POIカテゴリ（純正）を供給するクロージャ
    let poiCategory: (Item) -> MKPointOfInterestCategory?

    // 選択時コールバック
    let onSelect: (Item) -> Void

    @State private var selectedCategory: KKCategory? = nil
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            KKFilterBar(selected: $selectedCategory)
                .padding(.bottom, 8)

            // キーワード検索フィールド
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(L.Kokokamo.searchPlaceholder, text: $searchText)
                    .focused($isSearchFocused)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit {
                        isSearchFocused = false
                    }
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.bottom, 8)

            List(filteredItems, id: \.id) { p in
                Button { onSelect(p) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(name(p)).bold()

                        if let poi = poiCategory(p) {
                            // あなたの既存の日本語化拡張が使えます
                            Text(poi.localizedName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let addr = address(p), !addr.isEmpty {
                            Text(addr)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle(L.Kokokamo.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var filteredItems: [Item] {
        var result = items

        // カテゴリフィルタ
        if let sel = selectedCategory {
            result = result.filter {
                poiCategory($0)?.kkCategory ?? .other == sel
            }
        }

        // キーワード検索
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            result = result.filter {
                name($0).localizedCaseInsensitiveContains(trimmedQuery)
            }
        }

        return result
    }
}

/// 上部の3カテゴリトグル（そのまま）
//private struct KKFilterBar: View {
//    @Binding var selected: KKCategory?
//
//    var body: some View {
//        HStack(spacing: 8) {
//            ForEach(KKCategory.allCases) { cat in
//                let isOn = (selected == cat)
//                Button {
//                    selected = isOn ? nil : cat
//                } label: {
//                    HStack(spacing: 6) {
//                        Image(systemName: isOn ? "largecircle.fill.circle" : "circle")
//                        Text(cat.rawValue)
//                            .font(.subheadline)
//                            .fontWeight(isOn ? .semibold : .regular)
//                    }
//                    .padding(.horizontal, 12).padding(.vertical, 8)
//                    .background(isOn ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
//                    .clipShape(Capsule())
//                }
//                .buttonStyle(.plain)
//            }
//            Spacer(minLength: 0)
//        }
//        .padding(.horizontal)
//    }
//}

// KKCategory の見た目設定（アイコン＆色）
public extension KKCategory {
    /// ベースの丸アイコン名（押下時は ".fill" を付ける）
    var symbolBase: String {
        switch self {
        case .food:        return "fork.knife.circle"
        case .sightseeing: return "camera.circle"
        case .other:       return "square.grid.2x2"
        }
    }
    /// 選択時の色
    var highlightColor: Color {
        switch self {
        case .food:        return .orange
        case .sightseeing: return .blue
        case .other:       return .gray
        }
    }
}

/// アイコンのみ／アイコン＋ラベルの両対応フィルタバー
struct KKFilterBar: View {
    @Binding var selected: KKCategory?
    var showLabels: Bool = true   // ラベル表示切り替え

    var body: some View {
        HStack(spacing: 16) {
            ForEach(KKCategory.allCases) { cat in
                let isOn = (selected == cat)
                Button {
                    // 軽い触覚フィードバック（任意）
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    #endif
                    selected = isOn ? nil : cat
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: cat.symbolBase + (isOn ? ".fill" : ""))
                            .font(.title2) // アイコンサイズ
                            .foregroundStyle(isOn ? Color.white : Color.primary)
                            .padding(10)
                            .background(
                                Circle()
                                    .fill(isOn ? cat.highlightColor : Color(.systemGray5))
                            )
                            .shadow(color: isOn ? cat.highlightColor.opacity(0.3) : .clear,
                                    radius: isOn ? 6 : 0, x: 0, y: 2)

                        if showLabels {
                            Text(cat.localizedName)
                                .font(.caption)
                                .foregroundStyle(isOn ? cat.highlightColor : .secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(cat.localizedName))
                .accessibilityValue(Text(isOn ? L.Kokokamo.selected : L.Kokokamo.notSelected))
                .accessibilityHint(Text(isOn ? L.Kokokamo.tapToDeselect : L.Kokokamo.tapToSelect))
                .animation(.easeOut(duration: 0.15), value: isOn)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
    }
}
