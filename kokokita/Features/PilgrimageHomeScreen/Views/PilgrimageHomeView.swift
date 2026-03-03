import SwiftUI

// 巡礼モードのホーム画面（コース一覧 + CTA）
// ストアを所有し、navigationDestination をルートに配置（CourseListView が非ルートのため）
struct PilgrimageHomeView: View {
    @State private var store = CourseListStore()
    @State private var showCourseList = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // ヒーローエリア
                    VStack(spacing: 12) {
                        Image(systemName: "figure.walk.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.orange)

                        Text(L.PilgrimageHome.heroTitle)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)

                        Text(L.PilgrimageHome.heroDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    .padding(.top, 24)

                    // コース一覧へのCTA
                    Button {
                        showCourseList = true
                    } label: {
                        Label(L.PilgrimageHome.viewCourses, systemImage: "list.bullet")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle(L.Tab.home)
            .navigationDestination(isPresented: $showCourseList) {
                CourseListView(store: store)
            }
            // UUID（コースID）ナビゲーションをルートで処理
            // CourseListView は非ルートのため、ここで定義する必要がある
            .navigationDestination(for: UUID.self) { courseId in
                if let course = store.courses.first(where: { $0.id == courseId }) {
                    CourseDetailView(course: course, store: store)
                }
            }
        }
    }
}
