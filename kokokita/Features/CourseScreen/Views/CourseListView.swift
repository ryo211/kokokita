import SwiftUI

// コース一覧画面
// navigationDestination は呼び出し元の NavigationStack ルートに配置すること
struct CourseListView: View {
    @Bindable var store: CourseListStore
    var showTitle: Bool = true

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
                }
            }
        }
        .navigationTitle(showTitle ? L.Course.title : "")
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
            // 達成状況インジケーター
            Circle()
                .fill(course.isCompleted ? Color.indigo : Color.secondary.opacity(0.3))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(course.title)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text("\(course.totalSpotCount)\(L.Course.spotsCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if course.checkedInCount > 0 {
                        Text("✓ \(course.checkedInCount)")
                            .font(.caption.bold())
                            .foregroundStyle(.indigo)
                    }
                }
            }

            Spacer()

            // 達成率プログレスバー
            if course.totalSpotCount > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(course.completionRate * 100))%")
                        .font(.caption2.bold())
                        .foregroundStyle(.indigo)

                    ProgressView(value: course.completionRate)
                        .progressViewStyle(.linear)
                        .frame(width: 60)
                        .tint(.indigo)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
