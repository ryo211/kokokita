import SwiftUI

// コース一覧画面（有効化トグル付き）
// 記録モードの RootTabView のコースタブ、および巡礼モードのホームから遷移する
struct CourseListView: View {
    @State private var store = CourseListStore()

    var body: some View {
        List {
            if store.courses.isEmpty {
                ContentUnavailableView(
                    L.Course.emptyTitle,
                    systemImage: "list.bullet",
                    description: Text(L.Course.emptyDescription)
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(store.courses) { course in
                    NavigationLink(value: course.id) {
                        CourseRowView(course: course)
                    }
                    .swipeActions(edge: .leading) {
                        // 有効/無効切り替えをスワイプアクションでも可能に
                        Button {
                            store.toggleEnabled(course)
                        } label: {
                            Label(
                                course.isEnabled ? L.Course.disable : L.Course.enable,
                                systemImage: course.isEnabled ? "xmark.circle" : "checkmark.circle"
                            )
                        }
                        .tint(course.isEnabled ? .gray : .orange)
                    }
                }
            }
        }
        .navigationTitle(L.Course.title)
        .navigationDestination(for: UUID.self) { courseId in
            if let course = store.courses.first(where: { $0.id == courseId }) {
                CourseDetailView(course: course, store: store)
            }
        }
        .alert(L.Common.error, isPresented: $store.showError) {
            Button(L.Common.ok) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
        .task {
            await store.load()
        }
        .sheet(item: $store.retroactiveResult) { result in
            RetroactiveCheckInResultSheet(result: result)
        }
    }
}

// コース行ビュー
private struct CourseRowView: View {
    let course: Course

    var body: some View {
        HStack(spacing: 12) {
            // 有効化インジケーター
            Circle()
                .fill(course.isEnabled ? Color.orange : Color.secondary.opacity(0.3))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(course.title)
                    .font(.headline)
                    .foregroundStyle(course.isEnabled ? .primary : .secondary)

                HStack(spacing: 8) {
                    Text("\(course.totalSpotCount)\(L.Course.spotsCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if course.checkedInCount > 0 {
                        Text("✓ \(course.checkedInCount)")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            // 達成率プログレスバー
            if course.totalSpotCount > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(course.completionRate * 100))%")
                        .font(.caption2.bold())
                        .foregroundStyle(course.isEnabled ? .orange : .secondary)

                    ProgressView(value: course.completionRate)
                        .progressViewStyle(.linear)
                        .frame(width: 60)
                        .tint(course.isEnabled ? .orange : .secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(course.isEnabled ? 1.0 : 0.6)
    }
}
