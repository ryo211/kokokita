import SwiftUI

// 記録モードのコースタブ（CourseListViewのラッパー）
struct CourseScreen: View {
    var body: some View {
        NavigationStack {
            CourseListView()
        }
    }
}
