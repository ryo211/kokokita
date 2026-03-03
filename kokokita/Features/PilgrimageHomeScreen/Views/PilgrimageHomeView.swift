import SwiftUI

// 巡礼モードのホーム画面（コース一覧 + CTA）
// isPresented と値ベースナビゲーションの混在を避けるため、
// NavigationLink(value:) で統一する
struct PilgrimageHomeView: View {
    @State private var store = CourseListStore()

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

                    // コース一覧へのCTA（値ベースナビゲーション）
                    NavigationLink(value: PilgrimageHomeRoute.courseList) {
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
            // コース一覧ルート
            .navigationDestination(for: PilgrimageHomeRoute.self) { _ in
                CourseListView(store: store)
            }
            // コース詳細ルート（CourseListView が非ルートのためここで処理）
            .navigationDestination(for: UUID.self) { courseId in
                if let course = store.courses.first(where: { $0.id == courseId }) {
                    CourseDetailView(course: course, store: store)
                }
            }
        }
    }
}

private enum PilgrimageHomeRoute: Hashable {
    case courseList
}
