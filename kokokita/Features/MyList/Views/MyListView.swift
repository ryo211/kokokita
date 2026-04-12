import SwiftUI
import CoreData

/// ユーザーが作成したコースの一覧画面
struct MyListView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CourseEntity.createdAt, ascending: true)],
        predicate: NSPredicate(format: "isUserCreated == YES"),
        animation: .default
    )
    private var courses: FetchedResults<CourseEntity>

    @State private var showCreateEditor = false
    @State private var deletingCourse: CourseEntity?
    @State private var showDeleteConfirm = false

    private let repo = AppContainer.shared.courseRepo

    var body: some View {
        Group {
            if courses.isEmpty {
                emptyState
            } else {
                courseList
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.square.on.square")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.indigo)
                    Text(L.MyList.title)
                        .font(.headline)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCreateEditor = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
                .accessibilityLabel(L.MyList.newCourseButton)
            }
        }
        .navigationDestination(isPresented: $showCreateEditor) {
            CourseEditorView(mode: .create)
        }
        .confirmationDialog(
            L.MyList.deleteConfirmTitle,
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(L.Common.delete, role: .destructive) {
                if let course = deletingCourse {
                    deleteCourse(course)
                }
            }
            Button(L.Common.cancel, role: .cancel) {}
        } message: {
            Text(L.MyList.deleteConfirmMessage)
        }
    }

    // MARK: - コース一覧

    private var courseList: some View {
        List {
            ForEach(courses) { course in
                NavigationLink {
                    CourseEditorView(mode: .edit(courseId: course.id ?? UUID()))
                } label: {
                    MyListCourseRowView(course: course)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        deletingCourse = course
                        showDeleteConfirm = true
                    } label: {
                        Label(L.Common.delete, systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - 空状態

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.text.rectangle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text(L.MyList.emptyTitle)
                .font(.headline)
                .foregroundStyle(.primary)

            Button {
                showCreateEditor = true
            } label: {
                Text(L.MyList.emptyDescription)
                    .font(.subheadline)
                    .foregroundStyle(.indigo)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 削除処理

    private func deleteCourse(_ entity: CourseEntity) {
        guard let id = entity.id else { return }
        do {
            try repo.delete(id)
        } catch {
            Logger.error("コース削除失敗: \(error)")
        }
    }
}
