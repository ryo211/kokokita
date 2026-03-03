import SwiftUI

// 記録モードのコースタブ（CourseListViewのラッパー）
// ストアを所有し、navigationDestination をルートに配置
struct CourseScreen: View {
    @State private var store = CourseListStore()

    var body: some View {
        NavigationStack {
            CourseListView(store: store)
                .navigationDestination(for: UUID.self) { courseId in
                    if let course = store.courses.first(where: { $0.id == courseId }) {
                        CourseDetailView(course: course, store: store)
                    }
                }
        }
    }
}
