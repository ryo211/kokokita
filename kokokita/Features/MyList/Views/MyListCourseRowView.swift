import SwiftUI
import CoreData

/// マイリスト画面のコース行セル
struct MyListCourseRowView: View {
    @ObservedObject var course: CourseEntity
    private let repo = AppContainer.shared.courseRepo

    var body: some View {
        HStack(spacing: 12) {
            // カバー画像またはプレースホルダー
            coverImageView
                .frame(width: 96, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // テキスト情報
            VStack(alignment: .leading, spacing: 4) {
                Text(course.title ?? "")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                Text(spotsCountText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 有効/無効トグル
            Toggle("", isOn: Binding(
                get: { course.isEnabled?.boolValue ?? false },
                set: { newValue in
                    toggleEnabled(newValue)
                }
            ))
            .labelsHidden()
            .tint(.indigo)
        }
    }

    // MARK: - カバー画像

    @ViewBuilder
    private var coverImageView: some View {
        if let path = course.localCoverImagePath,
           let uiImage = LocalImageStorage.shared.load(from: path) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.indigo.opacity(0.15))
                Image(systemName: "person.text.rectangle")
                    .font(.title2)
                    .foregroundStyle(Color.indigo.opacity(0.6))
            }
        }
    }

    // MARK: - スポット数テキスト

    private var spotsCountText: String {
        let count = spotCount
        return L.MyList.spotsCount(count)
    }

    private var spotCount: Int {
        // セクション経由でスポットを集計
        let sections = (course.sections?.array as? [CourseSectionEntity]) ?? []
        let sectionCount = sections.reduce(0) { $0 + (($1.spots?.count) ?? 0) }
        // v3 互換: course.spots 直下
        let legacyCount = course.spots?.count ?? 0
        return sections.isEmpty ? legacyCount : sectionCount
    }

    // MARK: - isEnabled 更新

    private func toggleEnabled(_ newValue: Bool) {
        course.isEnabled = NSNumber(value: newValue)
        try? CoreDataStack.shared.context.save()
        NotificationCenter.default.post(name: .courseChanged, object: nil)
    }
}
