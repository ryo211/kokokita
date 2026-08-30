import SwiftUI

// 達成済みスポット1件分のスタンプカード（御朱印帳風）
struct StampCard: View {
    let course: Course
    let spot: CourseSpot

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            courseCoverImage(
                localPath: spot.localCoverImagePath,
                remoteURLString: spot.coverImageUrl,
                placeholder: { coverPlaceholder }
            )

            LinearGradient(
                colors: [Color.black.opacity(0.05), Color.black.opacity(0.30), Color.black.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )

            // ハンコ（少し右上寄りに大きく重ねて「押した」存在感を出す）
            Image("kokokita_hanko")
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)
                .rotationEffect(.degrees(-11))
                .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 6)
                .padding(.trailing, -4)

            VStack(alignment: .leading, spacing: 3) {
                Text(course.title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)

                Text(spot.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.3), radius: 2)

                if let achievedAt = spot.firstCheckedInAt {
                    Text(achievedAt, format: .dateTime.year().month().day())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.22), in: Capsule())
                }
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fill)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            // 手帳にあらかじめ印刷された「マス目」に見立てた実線の枠
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.indigo.opacity(0.6), lineWidth: 2.5)
        }
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }

    private var coverPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.indigo.opacity(0.85), Color.indigo.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(.white.opacity(0.3))
        }
    }
}

// まだスタンプが押されていない「空欄マス目」
// 常に数枚を残しておくことで、手帳のようにあらかじめマス目が用意されている見た目にする
struct EmptyStampSlot: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.secondarySystemBackground).opacity(0.5))

            Image("kokokita_hanko")
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .opacity(0.14)
                .grayscale(1.0)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fill)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                .foregroundStyle(Color.indigo.opacity(0.25))
        }
    }
}
