import SwiftUI

// 遡り判定結果シート
// コースを初めて有効化した時に過去記録からチェックインが認定された場合に表示
struct RetroactiveCheckInResultSheet: View {
    let result: RetroactiveResultItem

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 遡りアイコン
                    VStack(spacing: 12) {
                        Image(systemName: "clock.badge.checkmark.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.orange)

                        Text(L.CheckIn.retroactiveTitle)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)

                        Text(L.CheckIn.retroactiveSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    .padding(.top, 24)

                    // コース名
                    Text(result.course.title)
                        .font(.headline)
                        .padding(.horizontal, 20)

                    // チェックインされたスポット一覧
                    VStack(spacing: 0) {
                        ForEach(result.checkedInSpots) { spot in
                            RetroactiveSpotRow(spot: spot)
                            if spot.id != result.checkedInSpots.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)

                    // 達成状況
                    HStack {
                        Text(L.Course.progress)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(result.course.checkedInCount)/\(result.course.totalSpotCount)")
                            .font(.subheadline.bold())
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.Common.close) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct RetroactiveSpotRow: View {
    let spot: CourseSpot

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(.orange)
                .font(.system(size: 22))

            VStack(alignment: .leading, spacing: 2) {
                Text(spot.name)
                    .font(.headline)

                if let date = spot.firstCheckedInAt {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        + Text(L.CheckIn.retroactiveDateSuffix)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(16)
    }
}
