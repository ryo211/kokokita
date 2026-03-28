import SwiftUI

// チェックイン達成通知シート
// 通常記録時にコーススポットへのチェックインが成功した場合に表示
struct CheckInResultSheet: View {
    let results: [CourseRecognitionService.RecognitionResult]
    var onDismiss: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 達成アイコン
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.indigo)
                            .symbolEffect(.bounce, value: true)

                        Text(L.CheckIn.resultTitle)
                            .font(.title2.bold())

                        Text(L.CheckIn.resultSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    // チェックインしたスポット一覧
                    VStack(spacing: 0) {
                        ForEach(results, id: \.spot.id) { result in
                            CheckInResultRow(result: result)
                            if result.spot.id != results.last?.spot.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)

                    Spacer(minLength: 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.Common.close) {
                        onDismiss?()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct CheckInResultRow: View {
    let result: CourseRecognitionService.RecognitionResult

    var body: some View {
        HStack(spacing: 12) {
            // スポット画像またはチェックマークアイコン
            if let urlStr = result.spot.coverImageUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 96, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        spotIconPlaceholder
                    }
                }
            } else {
                spotIconPlaceholder
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(result.spot.name)
                    .font(.headline)
                Text(result.course.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(format: L.CheckIn.distanceFormat, Int(result.distanceMeters)))
                    .font(.caption2)
                    .foregroundStyle(.indigo)
            }

            Spacer()

            // コース達成率
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(result.course.checkedInCount)/\(result.course.totalSpotCount)")
                    .font(.caption.bold())
                ProgressView(value: result.course.completionRate)
                    .progressViewStyle(.linear)
                    .frame(width: 60)
                    .tint(.indigo)
            }
        }
        .padding(16)
    }

    private var spotIconPlaceholder: some View {
        Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.indigo)
            .font(.system(size: 24))
            .frame(width: 96, height: 64)
    }
}
