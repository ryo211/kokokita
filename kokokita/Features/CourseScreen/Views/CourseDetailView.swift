import SwiftUI

// コース詳細画面（スポットリスト + 達成状況）
struct CourseDetailView: View {
    let course: Course
    @Bindable var store: CourseListStore

    var body: some View {
        List {
            // コース概要セクション
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    if let summary = course.summary {
                        Text(summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // 達成状況
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L.Course.progress)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(course.checkedInCount) / \(course.totalSpotCount)")
                                .font(.title3.bold())
                        }

                        Spacer()

                        // 円形プログレス
                        ZStack {
                            Circle()
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 6)
                            Circle()
                                .trim(from: 0, to: course.completionRate)
                                .stroke(Color.orange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text("\(Int(course.completionRate * 100))%")
                                .font(.caption.bold())
                        }
                        .frame(width: 56, height: 56)
                    }

                    if course.isCompleted {
                        Label(L.Course.completed, systemImage: "checkmark.seal.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.vertical, 4)
            }

            // 有効化トグルセクション
            Section {
                Toggle(isOn: Binding(
                    get: { course.isEnabled },
                    set: { _ in store.toggleEnabled(course) }
                )) {
                    Label(L.Course.enableToggle, systemImage: "checkmark.circle")
                }
                .tint(.orange)
            } header: {
                Text(L.Course.settingsSection)
            }

            // スポット一覧セクション
            Section {
                ForEach(course.spots) { spot in
                    SpotRowView(spot: spot)
                }
            } header: {
                Text(L.Course.spotsSection)
            }
        }
        .navigationTitle(course.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// スポット行ビュー
private struct SpotRowView: View {
    let spot: CourseSpot

    var body: some View {
        HStack(spacing: 12) {
            // チェックインアイコン
            Image(systemName: spot.isCheckedIn ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(spot.isCheckedIn ? .orange : .secondary)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text(spot.name)
                    .font(.body)
                    .foregroundStyle(spot.isCheckedIn ? .primary : .primary)

                if let desc = spot.spotDescription {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let date = spot.firstCheckedInAt {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            Text("\(spot.orderIndex + 1)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .opacity(spot.isCheckedIn ? 1.0 : 0.8)
    }
}
