import SwiftUI

/// 近くの訪問記録を横スクロールで表示するカルーセル
///
/// 詳細画面の「近くの場所」セクションで使用。
/// 縦型クリアブルーカードを横スクロールで表示する。
///
/// - iOS 17+: `scrollTargetBehavior(.viewAligned)` でスナップ動作
/// - iOS 16: 通常のScrollView
struct NearbyVisitsCarousel: View {
    /// 表示する訪問記録
    let visits: [VisitAggregate]

    /// 訪問詳細データ（NavigationLink用）
    let visitsData: [VisitDetailData]

    /// カード間のスペース
    var spacing: CGFloat = 12

    /// 水平パディング
    var horizontalPadding: CGFloat = 16

    // 編集・削除の状態管理
    @State private var editingTarget: VisitAggregate? = nil
    @State private var pendingDeleteVisitId: UUID? = nil
    @State private var showDeleteConfirm = false

    // MARK: - Body

    var body: some View {
        Group {
            if #available(iOS 17, *) {
                ios17Carousel
            } else {
                ios16Carousel
            }
        }
        // 編集シート
        .sheet(item: $editingTarget) { target in
            EditView(aggregate: target) {
                editingTarget = nil
                NotificationCenter.default.post(name: .visitsChanged, object: nil)
            }
            .iPadSheetSize()
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        // 削除確認アラート（カルーセル側では不要：VisitDetailScreen内で確認済み）
    }

    // MARK: - iOS 17+ Implementation

    @available(iOS 17, *)
    private var ios17Carousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing) {
                ForEach(Array(visits.enumerated()), id: \.element.visit.id) { index, visit in
                    if index < visitsData.count {
                        NavigationLink {
                            VisitDetailScreen(
                                data: visitsData[index],
                                visitId: visit.visit.id,
                                onEdit: { editingTarget = visit },
                                onDelete: {
                                    deleteVisit(id: visit.visit.id)
                                },
                                onUpdate: {
                                    NotificationCenter.default.post(name: .visitsChanged, object: nil)
                                }
                            )
                        } label: {
                            ClearBlueVerticalCard(aggregate: visit)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, horizontalPadding)
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollClipDisabled()
        .frame(height: VisitCardStyle.verticalCardHeight + 20) // カード高さ + シャドウ用マージン
    }

    // MARK: - iOS 16 Fallback

    private var ios16Carousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing) {
                ForEach(Array(visits.enumerated()), id: \.element.visit.id) { index, visit in
                    if index < visitsData.count {
                        NavigationLink {
                            VisitDetailScreen(
                                data: visitsData[index],
                                visitId: visit.visit.id,
                                onEdit: { editingTarget = visit },
                                onDelete: {
                                    deleteVisit(id: visit.visit.id)
                                },
                                onUpdate: {
                                    NotificationCenter.default.post(name: .visitsChanged, object: nil)
                                }
                            )
                        } label: {
                            ClearBlueVerticalCard(aggregate: visit)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, horizontalPadding)
        }
        .frame(height: VisitCardStyle.verticalCardHeight + 20)
    }

    // MARK: - 削除処理

    private func deleteVisit(id: UUID) {
        do {
            try AppContainer.shared.repo.delete(id: id)
        } catch {
            Logger.error("カルーセルからの記録削除に失敗", error: error)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("近くの訪問カルーセル") {
    NavigationStack {
        VStack(alignment: .leading, spacing: 16) {
            Text("近くの過去記録")
                .font(.headline)
                .padding(.horizontal)

            NearbyVisitsCarousel(
                visits: [.preview, .preview, .preview],
                visitsData: []
            )
        }
    }
}
#endif
