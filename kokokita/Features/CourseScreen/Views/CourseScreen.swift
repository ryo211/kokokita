import SwiftUI

// 記録モードのコースタブ（CourseListViewのラッパー）
// ストアを所有し、navigationDestination をルートに配置
// 遡り判定シートはここに配置（NavigationStack 外）して CourseStoreSheet との競合を回避
struct CourseScreen: View {
    /// 外部から注入されるストア（nilの場合は内部で生成）
    var externalStore: CourseListStore? = nil
    @State private var ownStore = CourseListStore()

    private var store: CourseListStore { externalStore ?? ownStore }

    var body: some View {
        NavigationStack {
            CourseListView(store: store)
                .navigationDestination(for: UUID.self) { courseId in
                    if let course = store.courses.first(where: { $0.id == courseId }) {
                        // courseListStore を渡し、詳細を開いたタイミングで遡り判定シートを表示
                        CourseDetailView(course: course, courseListStore: store, showSummaryOnAppear: true)
                    }
                }
        }
        .onReceive(NotificationCenter.default.publisher(for: .courseChanged)) { _ in
            Task { await store.load() }
        }
    }
}
