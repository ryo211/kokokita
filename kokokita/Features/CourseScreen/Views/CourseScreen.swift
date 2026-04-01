import SwiftUI

// 記録モードのコースタブ（CourseListViewのラッパー）
// ストアを所有し、navigationDestination をルートに配置
// 遡り判定シートはここに配置（NavigationStack 外）して CourseStoreSheet との競合を回避
struct CourseScreen: View {
    @State private var store = CourseListStore()

    var body: some View {
        NavigationStack {
            CourseListView(store: store)
                .navigationDestination(for: UUID.self) { courseId in
                    if let course = store.courses.first(where: { $0.id == courseId }) {
                        // courseListStore を渡し、詳細を開いたタイミングで遡り判定シートを表示
                        CourseDetailView(course: course, courseListStore: store)
                    }
                }
        }
    }
}
