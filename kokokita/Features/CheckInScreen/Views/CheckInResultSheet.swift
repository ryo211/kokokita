import SwiftUI

// チェックイン達成通知シート
// 通常記録時にコーススポットへのチェックインが成功した場合に表示
struct CheckInResultSheet: View {
    let results: [CourseRecognitionService.RecognitionResult]
    let visitId: UUID
    var onDismiss: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var showShare = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    sheetHeader
                        .padding(.top, 8)
                        .padding(.bottom, 0)

                    LazyVStack(spacing: 14) {
                        ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                            StampedCheckInCard(
                                result: result,
                                visitId: visitId,
                                stampDelay: Double(index) * 0.18
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 36)
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
        .iPadSheetSize(iPhoneDetents: [.medium, .large])
        .sheet(isPresented: $showShare) {
            if let first = results.first {
                SpotSharePreviewSheet(spot: first.spot, course: first.course, achievement: first.spotAchievementInfo)
            }
        }
    }

    // ヘッダー：チェックマーク＋テキスト＋達成共有ボタン（ハンコはシート全体の背景に配置）
    // 共有ボタンは通常のレイアウトフロー内に置くことで、オーバーレイ配置による
    // 他要素との重なりを避け、常に確実な位置に表示されるようにしている
    private var sheetHeader: some View {
        VStack(spacing: 18) {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.indigo)
                    .symbolEffect(.bounce, value: true)

                Text(L.CheckIn.resultTitle)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)

                Text(L.CheckIn.stampAcquired)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            shareAchievementButton
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var shareAchievementButton: some View {
        Button {
            showShare = true
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "square.and.arrow.up.fill")
                    .font(.subheadline.weight(.semibold))
                Text(L.CheckIn.shareAchievement)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [Color.indigo, Color.indigo.opacity(0.82)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            )
            .overlay(
                Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: Color.indigo.opacity(0.35), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// スタンプ付きチェックインカード
private struct StampedCheckInCard: View {
    let result: CourseRecognitionService.RecognitionResult
    let visitId: UUID
    let stampDelay: Double

    // スタンプが「ズン！」と押されるアニメーション用状態
    @State private var stampScale: CGFloat = 0.05
    @State private var stampOpacity: Double = 0
    @State private var stampAngle: Double = -22

    // 到達順位（「◯人目」）。サーバーからの応答が遅れる・無い場合は表示しないだけなので
    // nilのままでも問題ない（記録詳細画面で後から確認できる）
    @State private var rank: Int?

    var body: some View {
        HStack(spacing: 14) {
            thumbnail
            infoArea
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        // clipShapeではなくbackgroundにシェイプを渡すことで、
        // スタンプがカード境界をはみ出してもクリップされない
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 4)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.indigo.opacity(0.09), lineWidth: 1)
        }
        // ハンコをカード右側のスポット名あたりに配置（白背景上なので常に視認可能・自然な重なり）
        .overlay(alignment: .trailing) {
            Image("kokokita_hanko")
                .resizable()
                .scaledToFit()
                .frame(width: 86, height: 86)
                .rotationEffect(.degrees(stampAngle))
                .scaleEffect(stampScale)
                .opacity(stampOpacity)
                .offset(x: -8)
        }
        // コース全制覇バッジ（カード上部に重ねて表示）
        .overlay(alignment: .top) {
            if result.course.isCompleted {
                allClearBadge
                    .offset(y: -13)
            }
        }
        .padding(.top, result.course.isCompleted ? 13 : 0)
        .task {
            // シート表示前に送信・応答が既に完了していた場合に備えて、ローカルの保存済み順位を確認する
            if let arrivals = try? AppContainer.shared.spotArrivalOutboxRepo.fetchByVisitId(visitId),
               let match = arrivals.first(where: { $0.spotId == result.spot.id }),
               let existingRank = match.rank {
                rank = existingRank
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .spotArrivalRankDetermined)
                .receive(on: DispatchQueue.main)
        ) { notification in
            guard let payload = notification.object as? SpotArrivalRankPayload else { return }
            guard payload.visitId == visitId && payload.spotId == result.spot.id else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                rank = payload.rank
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + stampDelay + 0.2) {
                // 第1フェーズ: ゆっくり降りてくる（落下）
                withAnimation(.spring(response: 0.55, dampingFraction: 0.58)) {
                    stampScale = 1.08
                    stampOpacity = 1.0
                    stampAngle = -14
                }
                // 第2フェーズ: 押しつけた後にわずかに跳ねて落ち着く
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                        stampScale = 1.0
                    }
                }
            }
        }
    }

    // サムネイル（写真のみ・ハンコはカード全体のoverlayで別途配置）
    private var thumbnail: some View {
        backgroundLayer
            .frame(width: 76, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
            }
    }

    // 情報エリア（SpotPanelListRow に合わせた構成: コース名 → スポット名 → 距離）
    private var infoArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            // コース名（マップアイコン付き）
            HStack(spacing: 4) {
                Image(systemName: "map.fill")
                    .font(.system(size: 10))
                Text(result.course.title)
                    .font(.caption)
                    .lineLimit(1)
            }
            .foregroundStyle(.indigo.opacity(0.75))

            // スポット名
            Text(result.spot.name)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(2)

            // 距離
            HStack(spacing: 2) {
                Image(systemName: "location.fill")
                    .font(.caption2)
                Text(String(format: L.CheckIn.distanceFormat, Int(result.distanceMeters)))
                    .font(.caption2.bold().monospacedDigit())
            }
            .foregroundStyle(.indigo)

            // 達成日時
            HStack(spacing: 2) {
                Image(systemName: "clock")
                    .font(.caption2)
                Text(result.achievedAt, format: .dateTime.year().month().day().hour().minute())
                    .font(.caption2.monospacedDigit())
            }
            .foregroundStyle(.secondary)

            // 到達順位（届いた場合のみ表示。届かない間は何も出さない）
            if let rank {
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.caption2)
                    Text(L.MetaCollection.rankFormat(rank))
                        .font(.caption2.bold())
                }
                .foregroundStyle(.orange)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // 全制覇バッジ（カード上部に浮かぶ）
    private var allClearBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "star.fill")
                .font(.caption2)
            Text(L.CheckIn.courseAllClear)
                .font(.caption.bold())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.orange)
                .shadow(color: .orange.opacity(0.45), radius: 5, y: 2)
        )
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        if let uiImage = result.spot.localCoverImagePath.flatMap({ LocalImageStorage.shared.load(from: $0) }) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else if let urlStr = result.spot.coverImageUrl, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    placeholderLayer
                }
            }
        } else {
            placeholderLayer
        }
    }

    private var placeholderLayer: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.90),
                    Color.accentColor.opacity(0.64),
                    Color.indigo.opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 76, weight: .thin))
                .foregroundStyle(.white.opacity(0.22))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 28)
                .padding(.trailing, 22)
        }
    }
}
