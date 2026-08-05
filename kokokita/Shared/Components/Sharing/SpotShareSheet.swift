import SwiftUI
import MapKit

// MARK: - 達成情報（スポット共有カードにスタンプ・実座標ピンを追加するための情報）

/// 達成済みスポットを共有する際に使う、実際にチェックインした際のGPS座標と日時。
/// コース定義上のspot.latitude/longitude（施設の正式な位置）とは別物。
struct SpotAchievementInfo {
    let coordinate: CLLocationCoordinate2D
    let achievedAt: Date
}

/// 達成日スタンプの見た目。丸いハンコスタンプ（achievementStamp）と形が被らないよう、
/// どれも円形は避けている。色調・フォントはカード全体のインディゴ基調・標準システムフォントに揃える
enum DateStampStyle: String, CaseIterable, Identifiable {
    case none
    /// 写真の右端に張り付くタブ（旧ribbon）
    case tab
    /// 写真の下端に張り付くプレート（旧shield）
    case plate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return L.Share.dateStampNone
        case .tab: return L.Share.dateStampTab
        case .plate: return L.Share.dateStampPlate
        }
    }
}

extension CourseRecognitionService.RecognitionResult {
    /// チェックイン達成通知（CheckInResultSheet）から共有する際、判定済みの実座標・達成日時をそのまま使う
    var spotAchievementInfo: SpotAchievementInfo {
        SpotAchievementInfo(
            coordinate: CLLocationCoordinate2D(latitude: visitLatitude, longitude: visitLongitude),
            achievedAt: achievedAt
        )
    }
}

// MARK: - スポット共有カード（ImageRenderer用）

struct SpotShareCard: View {
    let spot: CourseSpot
    let course: Course
    let coverImage: UIImage?
    /// 達成済みの場合のみ指定。ココキタスタンプ・達成日バッジの表示に使う
    var achievement: SpotAchievementInfo? = nil
    var showStamp: Bool = true
    var dateStampStyle: DateStampStyle = .tab

    static let cardWidth: CGFloat = 390

    var body: some View {
        VStack(spacing: 0) {
            photoSection
            contentSection
        }
        .frame(width: Self.cardWidth)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.indigo.opacity(0.75), Color.indigo.opacity(0.45), Color.indigo.opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2.5
                )
        )
    }

    private var photoSection: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let img = coverImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [Color.indigo.opacity(0.65), Color.indigo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .frame(width: Self.cardWidth, height: 220)
            .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: Self.cardWidth, height: 110)

            VStack(alignment: .leading, spacing: 3) {
                Text(course.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                Text(spot.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)

            if achievement != nil, showStamp {
                achievementStamp
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(14)
            }

            if let achievement, dateStampStyle != .none {
                // 配置はスタイルごとに異なる（リボンは右端、プレートは下端に張り付く）ため、
                // 各スタイルの実装側でframe/paddingを持たせている
                dateStampView(style: dateStampStyle, date: achievement.achievedAt)
            }
        }
        .frame(width: Self.cardWidth, height: 220)
        .clipped()
    }

    // MARK: - 達成スタンプ・日付スタンプ

    private var achievementStamp: some View {
        Image("kokokita_hanko")
            .resizable()
            .scaledToFit()
            .frame(width: 92, height: 92)
            .rotationEffect(.degrees(-12))
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }

    // 上部のハンコ（円形）と形が被らないよう、日付スタンプはどれも非円形にしている。
    // 色調はカードのインディゴグラデーション（枠線・CTA等）に揃え、フォントもタイトルと
    // 同じ標準システムフォント（rounded/serif不使用）に統一する
    @ViewBuilder
    private func dateStampView(style: DateStampStyle, date: Date) -> some View {
        switch style {
        case .none:
            EmptyView()
        case .tab:
            tabDateStamp(date)
        case .plate:
            plateDateStamp(date)
        }
    }

    // 右の壁から生えているタブ。角丸は壁と反対側（左）のみに付け、右端は完全にフラットにして
    // 写真の右端にぴったり張り付かせる。角度は付けない
    private func tabDateStamp(_ date: Date) -> some View {
        HStack(spacing: 5) {
            Text(date, format: .dateTime.month(.abbreviated).day())
                .font(.system(size: 13, weight: .heavy))
            Text(date, format: .dateTime.year())
                .font(.system(size: 10, weight: .semibold))
                .opacity(0.8)
        }
        .foregroundStyle(.white)
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .padding(.vertical, 8)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 10, bottomLeadingRadius: 10,
                bottomTrailingRadius: 0, topTrailingRadius: 0,
                style: .continuous
            )
            .fill(Color.indigo)
        )
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 10, bottomLeadingRadius: 10,
                bottomTrailingRadius: 0, topTrailingRadius: 0,
                style: .continuous
            )
            .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
        // .trailing（縦センタリング）+ bottom paddingでは「下からの余白を除いた範囲で中央寄せ」に
        // なってしまい、狙った下寄りの位置にならなかった。.bottomTrailingで直接下端基準に置く
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(.trailing, 0)
        .padding(.bottom, 20)
    }

    // 下の縁から生えてくるプレート。角丸は縁と反対側（上）のみに付け、下端は完全にフラットにして
    // 写真の下端にぴったり張り付かせる。角度は付けない
    private func plateDateStamp(_ date: Date) -> some View {
        VStack(spacing: 2) {
            Text(L.Share.achievedLabel)
                .font(.system(size: 8, weight: .bold))
                .tracking(1.6)
                .opacity(0.9)
            Text(date, format: .dateTime.month(.abbreviated).day())
                .font(.system(size: 14, weight: .heavy))
            Text(date, format: .dateTime.year())
                .font(.system(size: 8, weight: .semibold))
                .opacity(0.75)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 13)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 14, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 14,
                style: .continuous
            )
            .fill(Color.indigo)
        )
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 14, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 14,
                style: .continuous
            )
            .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(.trailing, 20)
        .padding(.bottom, 0)
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let address = spot.address, !address.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.indigo)
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            if let desc = spot.spotDescription, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack(spacing: 0) {
                Image("kokokita-app-icon-clearBlueDeep")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(L.App.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.indigo)
                    .padding(.leading, 8)
                Spacer()
                AppStoreBadgeView()
            }
        }
        .padding(16)
        .frame(width: Self.cardWidth, alignment: .leading)
    }
}

// MARK: - コース共有カード（ImageRenderer用）

struct CourseShareCard: View {
    let course: Course
    let coverImage: UIImage?

    static let cardWidth: CGFloat = 390

    var body: some View {
        VStack(spacing: 0) {
            photoSection
            contentSection
        }
        .frame(width: Self.cardWidth)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.indigo.opacity(0.75), Color.indigo.opacity(0.45), Color.indigo.opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2.5
                )
        )
    }

    private var photoSection: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let img = coverImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [Color.indigo.opacity(0.6), Color.indigo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .frame(width: Self.cardWidth, height: 220)
            .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: Self.cardWidth, height: 120)

            VStack(alignment: .leading, spacing: 4) {
                Text(course.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(L.Share.spotCountLabel(course.totalSpotCount))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .frame(width: Self.cardWidth, height: 220)
        .clipped()
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let summary = course.summary, !summary.isEmpty {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack(spacing: 0) {
                Image("kokokita-app-icon-clearBlueDeep")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(L.App.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.indigo)
                    .padding(.leading, 8)
                Spacer()
                AppStoreBadgeView()
            }
        }
        .padding(16)
        .frame(width: Self.cardWidth, alignment: .leading)
    }
}

// MARK: - 訪問記録共有カード（ImageRenderer用）

struct VisitShareCard: View {
    enum HeroLayout: Hashable { case photo, map }

    let data: VisitDetailData
    let coverImage: UIImage?
    let mapImage: UIImage?
    var heroLayout: HeroLayout = .photo
    var showSubThumbnail: Bool = true

    static let cardWidth: CGFloat = 390
    private static let heroHeight: CGFloat = 240

    var body: some View {
        VStack(spacing: 0) {
            heroSection
            if hasDetails { detailSection }
            footerSection
        }
        .frame(width: Self.cardWidth)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        // 証明書感のあるグラデーションボーダー
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.75),
                            Color(red: 0.25, green: 0.35, blue: 0.9).opacity(0.45),
                            Color.blue.opacity(0.75)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2.5
                )
        )
    }

    private var hasDetails: Bool {
        !(data.address ?? "").isEmpty || !(data.memo ?? "").isEmpty
    }

    // MARK: - ヒーロー（写真+小地図 or 地図メイン or グラデーション）

    @ViewBuilder
    private var heroSection: some View {
        switch heroLayout {
        case .photo:
            if let img = coverImage {
                photoHeroSection(img)
            } else if let mapImg = mapImage {
                mapHeroSection(mapImg)
            } else {
                gradientHeroSection
            }
        case .map:
            if let mapImg = mapImage {
                mapHeroWithPhotoSection(mapImg)
            } else if let img = coverImage {
                photoHeroSection(img)
            } else {
                gradientHeroSection
            }
        }
    }

    // 写真メイン + 右上に小地図サムネイル
    private func photoHeroSection(_ img: UIImage) -> some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .bottomLeading) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: Self.cardWidth, height: Self.heroHeight)
                    .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.65)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(width: Self.cardWidth, height: Self.heroHeight)

                titleDateStack
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
            .frame(width: Self.cardWidth, height: Self.heroHeight)
            .clipped()

            // 右上: 小地図サムネイル（日本全体が見えるスケール）
            if showSubThumbnail, let mapImg = mapImage {
                smallMapThumbnail(mapImg)
                    .padding(14)
            }
        }
        .frame(width: Self.cardWidth, height: Self.heroHeight)
        .clipped()
    }

    // 地図メイン（写真なし）
    private func mapHeroSection(_ mapImg: UIImage) -> some View {
        ZStack(alignment: .bottomLeading) {
            Image(uiImage: mapImg)
                .resizable()
                .scaledToFill()
                .frame(width: Self.cardWidth, height: Self.heroHeight)
                .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(width: Self.cardWidth, height: Self.heroHeight)

            titleDateStack
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .frame(width: Self.cardWidth, height: Self.heroHeight)
        .clipped()
    }

    // 地図メイン + 右上に小写真サムネイル
    private func mapHeroWithPhotoSection(_ mapImg: UIImage) -> some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .bottomLeading) {
                Image(uiImage: mapImg)
                    .resizable()
                    .scaledToFill()
                    .frame(width: Self.cardWidth, height: Self.heroHeight)
                    .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.6)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(width: Self.cardWidth, height: Self.heroHeight)

                titleDateStack
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
            .frame(width: Self.cardWidth, height: Self.heroHeight)
            .clipped()

            // 右上: 小写真サムネイル
            if showSubThumbnail, let img = coverImage {
                smallMapThumbnail(img)
                    .padding(14)
            }
        }
        .frame(width: Self.cardWidth, height: Self.heroHeight)
        .clipped()
    }

    // グラデーション（写真・地図ともになし）
    private var gradientHeroSection: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color.blue.opacity(0.55), Color.blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: Self.cardWidth, height: Self.heroHeight)

            titleDateStack
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .frame(width: Self.cardWidth, height: Self.heroHeight)
    }

    // タイトル + 日付テキスト（共通）
    private var titleDateStack: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(data.timestamp.kokokitaVisitString)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text(data.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
        }
    }

    // 小地図サムネイル（写真右上オーバーレイ）
    private func smallMapThumbnail(_ img: UIImage) -> some View {
        Image(uiImage: img)
            .resizable()
            .scaledToFill()
            .frame(width: 115, height: 88)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 3)
    }

    // MARK: - 詳細（住所・メモ）

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let address = data.address, !address.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            if let memo = data.memo, !memo.isEmpty {
                Text(memo)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: Self.cardWidth, alignment: .leading)
    }

    // MARK: - フッター（鳥ロゴ + アプリ名 + App Store バッジ）

    private var footerSection: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                Image("kokokita_irodori_blue")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                Text(L.App.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.blue)
                    .padding(.leading, 6)
                Spacer()
                AppStoreBadgeView()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}

// MARK: - スポット共有プレビューシート

struct SpotSharePreviewSheet: View {
    let spot: CourseSpot
    let course: Course
    /// 達成情報を明示的に渡す場合（達成通知シートからの共有など、実座標・達成日時が既に判明している場合）に使用。
    /// nilの場合でもspot.isCheckedInがtrueなら.task内で自動的に解決する
    var achievement: SpotAchievementInfo? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var coverImage: UIImage? = nil
    @State private var mapImage: UIImage? = nil
    @State private var renderedShareImage: UIImage? = nil
    @State private var isRendering = false
    @State private var editableText: String = ""
    @State private var showMapEditor = false
    @State private var resolvedAchievement: SpotAchievementInfo? = nil
    @State private var showStamp = true
    @State private var dateStampStyle: DateStampStyle = .tab

    private var effectiveAchievement: SpotAchievementInfo? { achievement ?? resolvedAchievement }
    private var hasMapContent: Bool { spot.hasValidCoordinate || effectiveAchievement != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    textPreviewSection
                    if effectiveAchievement != nil {
                        achievementSettingsSection
                    }
                    imagePreviewSection
                    if hasMapContent {
                        mapPreviewSection
                    }
                }
                .padding(.vertical, 16)
            }
            .navigationTitle(L.Share.previewTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L.Common.cancel) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        presentShareSheet(buildShareItems())
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .fontWeight(.semibold)
                    }
                    .disabled(renderedShareImage == nil)
                }
            }
        }
        .sheet(isPresented: $showMapEditor) {
            if hasMapContent {
                let coord = effectiveAchievement?.coordinate
                    ?? CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
                let radius = spot.recognitionRadiusMeters ?? course.recognitionRadiusMeters
                let displayRadius = max(radius * 8, 500)
                let region = MKCoordinateRegion(
                    center: coord,
                    latitudinalMeters: displayRadius,
                    longitudinalMeters: displayRadius
                )
                if effectiveAchievement != nil {
                    ShareMapEditorSheet(visitCoordinate: coord, initialRegion: region) { image in
                        mapImage = image
                    }
                } else {
                    ShareMapEditorSheet(spots: course.spots, initialRegion: region) { image in
                        mapImage = image
                    }
                }
            }
        }
        .task {
            editableText = L.Share.spotShareText(course.title, spot.name)
            if achievement == nil, spot.isCheckedIn {
                resolvedAchievement = await resolveAchievement()
            }
            await loadImages()
            await renderShareImage()
        }
        .onChange(of: showStamp) { _, _ in
            Task { await renderShareImage() }
        }
        .onChange(of: dateStampStyle) { _, _ in
            Task { await renderShareImage() }
        }
    }

    // MARK: - 達成演出の設定

    private var achievementSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L.Share.stampSettingsLabel, systemImage: "seal")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Toggle(isOn: $showStamp) {
                Text(L.Share.showStamp)
                    .font(.subheadline)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(L.Share.dateStampStyleLabel)
                    .font(.subheadline)
                Picker("", selection: $dateStampStyle) {
                    ForEach(DateStampStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - テキストプレビュー

    private var textPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L.Share.textLabel, systemImage: "text.quote")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextEditor(text: $editableText)
                .font(.subheadline)
                .frame(minHeight: 80)
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                .scrollContentBackground(.hidden)
        }
        .padding(.horizontal)
    }

    // MARK: - 共有画像プレビュー

    private var imagePreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L.Share.imageSection, systemImage: "photo")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if let rendered = renderedShareImage {
                Image(uiImage: rendered)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal)
                    .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
            } else if isRendering {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(40)
            }
        }
    }

    // MARK: - 地図プレビュー

    @ViewBuilder
    private var mapPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L.Share.mapTitle, systemImage: "map")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if let mapImg = mapImage {
                editableMapThumbnail(image: mapImg)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(24)
            }
        }
    }

    // MARK: - ヘルパー

    private func buildShareItems() -> [Any] {
        var items: [Any] = [editableText]
        if let img = renderedShareImage { items.append(img) }
        if let map = mapImage { items.append(map) }
        return items
    }

    @MainActor
    private func loadImages() async {
        if let path = spot.localCoverImagePath {
            coverImage = LocalImageStorage.shared.load(from: path)
        } else if let urlStr = spot.coverImageUrl, let url = URL(string: urlStr) {
            coverImage = await downloadImage(from: url)
        }

        let radius = spot.recognitionRadiusMeters ?? course.recognitionRadiusMeters
        let displayRadius = max(radius * 8, 500)

        if let achievement = effectiveAchievement {
            // 達成済み: コース定義上の座標ではなく、実際にチェックインした地点にピンを刺す
            let region = MKCoordinateRegion(
                center: achievement.coordinate,
                latitudinalMeters: displayRadius,
                longitudinalMeters: displayRadius
            )
            mapImage = await makeShareMapSnapshot(
                region: region, spots: [], orderNumbers: [:],
                pinCoordinate: achievement.coordinate, pinColor: .systemIndigo
            )
        } else if spot.hasValidCoordinate {
            let coord = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
            let region = MKCoordinateRegion(center: coord, latitudinalMeters: displayRadius, longitudinalMeters: displayRadius)
            let orderNumber = (course.spots.firstIndex(where: { $0.id == spot.id }) ?? 0) + 1
            mapImage = await makeShareMapSnapshot(region: region, spots: [spot], orderNumbers: [0: orderNumber])
        }
    }

    /// spot.visitIdsから実際のチェックイン記録（Visit）を取得し、達成情報として組み立てる
    @MainActor
    private func resolveAchievement() async -> SpotAchievementInfo? {
        guard let visitId = spot.visitIds.first,
              let visit = try? AppContainer.shared.repo.get(by: visitId) else { return nil }
        return SpotAchievementInfo(
            coordinate: CLLocationCoordinate2D(latitude: visit.visit.latitude, longitude: visit.visit.longitude),
            achievedAt: spot.firstCheckedInAt ?? visit.visit.timestampUTC
        )
    }

    @MainActor
    private func renderShareImage() async {
        isRendering = true
        defer { isRendering = false }
        let view = SpotShareCard(
            spot: spot, course: course, coverImage: coverImage,
            achievement: effectiveAchievement, showStamp: showStamp, dateStampStyle: dateStampStyle
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0
        renderedShareImage = renderer.uiImage
    }

    private func downloadImage(from url: URL) async -> UIImage? {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return UIImage(data: data)
    }
}

// MARK: - コース共有プレビューシート

struct CourseSharePreviewSheet: View {
    let course: Course
    @Environment(\.dismiss) private var dismiss

    @State private var coverImage: UIImage? = nil
    @State private var mapImage: UIImage? = nil
    @State private var renderedShareImage: UIImage? = nil
    @State private var isRendering = false
    @State private var editableText: String = ""
    @State private var showMapEditor = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // テキストプレビュー
                    VStack(alignment: .leading, spacing: 8) {
                        Label(L.Share.textLabel, systemImage: "text.quote")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextEditor(text: $editableText)
                            .font(.subheadline)
                            .frame(minHeight: 80)
                            .padding(10)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                            .scrollContentBackground(.hidden)
                    }
                    .padding(.horizontal)

                    // 共有画像プレビュー
                    VStack(alignment: .leading, spacing: 8) {
                        Label(L.Share.imageSection, systemImage: "photo")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        if let rendered = renderedShareImage {
                            Image(uiImage: rendered)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .padding(.horizontal)
                                .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
                        } else if isRendering {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(40)
                        }
                    }

                    // 地図プレビュー
                    VStack(alignment: .leading, spacing: 8) {
                        Label(L.Share.mapTitle, systemImage: "map")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        if let mapImg = mapImage {
                            editableMapThumbnail(image: mapImg)
                        } else {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(24)
                        }
                    }
                }
                .padding(.vertical, 16)
            }
            .navigationTitle(L.Share.previewTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L.Common.cancel) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        presentShareSheet(buildShareItems())
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .fontWeight(.semibold)
                    }
                    .disabled(renderedShareImage == nil)
                }
            }
        }
        .sheet(isPresented: $showMapEditor) {
            ShareMapEditorSheet(
                spots: course.spots,
                initialRegion: spotsFitRegion(course.spots)
            ) { image in
                mapImage = image
            }
        }
        .task {
            editableText = L.Share.courseShareText(course.title)
            await loadCoverImage()
            await renderShareImage()
            await generateCourseMap()
        }
    }

    private func buildShareItems() -> [Any] {
        var items: [Any] = [editableText]
        if let img = renderedShareImage { items.append(img) }
        if let map = mapImage { items.append(map) }
        return items
    }

    @MainActor
    private func loadCoverImage() async {
        if let path = course.localCoverImagePath {
            coverImage = LocalImageStorage.shared.load(from: path)
        } else if let urlStr = course.coverImageUrl, let url = URL(string: urlStr) {
            guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
            coverImage = UIImage(data: data)
        }
    }

    @MainActor
    private func renderShareImage() async {
        isRendering = true
        defer { isRendering = false }
        let view = CourseShareCard(course: course, coverImage: coverImage)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0
        renderedShareImage = renderer.uiImage
    }

    @MainActor
    private func generateCourseMap() async {
        let spots = course.spots
        guard !spots.isEmpty else { return }
        let region = spotsFitRegion(spots)
        let orderMap = Dictionary(uniqueKeysWithValues: spots.enumerated().map { ($0.offset, $0.offset + 1) })
        mapImage = await makeShareMapSnapshot(region: region, spots: spots, orderNumbers: orderMap)
    }
}

// MARK: - 地図サムネイル（タップで編集）

/// 共有プレビューシートで使う地図サムネイル共通ビュー
private func editableMapThumbnail(image: UIImage, action: (() -> Void)? = nil) -> some View {
    Button {
        action?()
    } label: {
        ZStack(alignment: .bottomTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // 編集ヒントバッジ
            Label(L.Share.mapEditHint, systemImage: "pencil")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(10)
        }
    }
    .buttonStyle(.plain)
    .padding(.horizontal)
    .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
}

// MARK: - View Extension（地図サムネイル呼び出しを簡潔に）

extension SpotSharePreviewSheet {
    func editableMapThumbnail(image: UIImage) -> some View {
        Sharing.editableMapThumbnail(image: image) { showMapEditor = true }
    }
}

extension CourseSharePreviewSheet {
    func editableMapThumbnail(image: UIImage) -> some View {
        Sharing.editableMapThumbnail(image: image) { showMapEditor = true }
    }
}

// ネームスペース用 enum（同名関数とViewから呼び分けるため）
private enum Sharing {
    static func editableMapThumbnail(image: UIImage, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Label(L.Share.mapEditHint, systemImage: "pencil")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(10)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
    }
}

// MARK: - 訪問記録共有プレビューシート

struct VisitSharePreviewSheet: View {
    let data: VisitDetailData
    @Environment(\.dismiss) private var dismiss

    @State private var photoImages: [UIImage] = []
    @State private var selectedPhotoIndex: Int = 0
    @State private var heroLayout: VisitShareCard.HeroLayout = .photo
    @State private var showSubThumbnail: Bool = true
    @State private var mapImage: UIImage? = nil
    @State private var renderedShareImage: UIImage? = nil
    @State private var isRendering = false
    @State private var editableText: String = ""
    @State private var showMapEditor = false

    private var currentCoverImage: UIImage? {
        selectedPhotoIndex < photoImages.count ? photoImages[selectedPhotoIndex] : nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    textPreviewSection
                    layoutSettingsSection
                    imagePreviewSection
                    if data.coordinate != nil {
                        mapPreviewSection
                    }
                }
                .padding(.vertical, 16)
            }
            .navigationTitle(L.Share.previewTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L.Common.cancel) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        presentShareSheet([editableText as Any] + (renderedShareImage.map { [$0] } ?? []))
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .fontWeight(.semibold)
                    }
                    .disabled(renderedShareImage == nil)
                }
            }
        }
        .sheet(isPresented: $showMapEditor) {
            if let coord = data.coordinate {
                let region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 36.5, longitude: 138.5),
                    span: MKCoordinateSpan(latitudeDelta: 24.0, longitudeDelta: 22.0)
                )
                ShareMapEditorSheet(visitCoordinate: coord, initialRegion: region) { image in
                    mapImage = image
                }
            }
        }
        .task {
            editableText = VisitDetailDataBuilder.shareText(data: data)
            await loadPhotos()
            await generateMapSnapshot()
            await renderVisitCard()
        }
        .onChange(of: mapImage) { _, _ in
            Task { await renderVisitCard() }
        }
        .onChange(of: heroLayout) { _, _ in
            Task { await renderVisitCard() }
        }
        .onChange(of: showSubThumbnail) { _, _ in
            Task { await renderVisitCard() }
        }
        .onChange(of: selectedPhotoIndex) { _, _ in
            Task { await renderVisitCard() }
        }
    }

    private var textPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L.Share.textLabel, systemImage: "text.quote")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextEditor(text: $editableText)
                .font(.subheadline)
                .frame(minHeight: 80)
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                .scrollContentBackground(.hidden)
        }
        .padding(.horizontal)
    }

    // MARK: - レイアウト設定

    private var layoutSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L.Share.layoutLabel, systemImage: "rectangle.stack")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Picker("", selection: $heroLayout) {
                Text(L.Share.layoutPhoto).tag(VisitShareCard.HeroLayout.photo)
                Text(L.Share.layoutMap).tag(VisitShareCard.HeroLayout.map)
            }
            .pickerStyle(.segmented)
            .disabled(photoImages.isEmpty)

            Toggle(isOn: $showSubThumbnail) {
                Text(L.Share.showSubThumbnail)
                    .font(.subheadline)
            }

            // 写真選択（2枚以上、かつ写真が表示に使われる場合）
            let showPhotoSelector = data.photoPaths.count >= 2
                && (heroLayout == .photo || showSubThumbnail)
            if showPhotoSelector && !photoImages.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L.Share.selectPhoto)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(photoImages.enumerated()), id: \.offset) { index, img in
                                Button {
                                    selectedPhotoIndex = index
                                } label: {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 64, height: 64)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(
                                                    selectedPhotoIndex == index ? Color.blue : Color.clear,
                                                    lineWidth: 3
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private var imagePreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L.Share.imageSection, systemImage: "photo")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if let rendered = renderedShareImage {
                Image(uiImage: rendered)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal)
                    .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
            } else if isRendering {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(40)
            }
        }
    }

    @ViewBuilder
    private var mapPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L.Share.mapTitle, systemImage: "map")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if let mapImg = mapImage {
                editableMapThumbnail(image: mapImg)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(24)
            }
        }
    }

    @MainActor
    private func loadPhotos() async {
        photoImages = data.photoPaths.compactMap { path in
            guard !path.isEmpty else { return nil }
            return ImageStore.load(path)
        }
        // 写真がない場合は地図メインにデフォルト設定
        if photoImages.isEmpty {
            heroLayout = .map
        }
    }

    @MainActor
    private func generateMapSnapshot() async {
        guard let coord = data.coordinate else { return }
        // 日本全体が見えるズームレベル（証明書感のある「ここに来た」表現）
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 36.5, longitude: 138.5),
            span: MKCoordinateSpan(latitudeDelta: 24.0, longitudeDelta: 22.0)
        )
        mapImage = await makeShareMapSnapshot(region: region, spots: [], orderNumbers: [:], pinCoordinate: coord)
    }

    @MainActor
    private func renderVisitCard() async {
        isRendering = true
        defer { isRendering = false }
        let card = VisitShareCard(
            data: data,
            coverImage: currentCoverImage,
            mapImage: mapImage,
            heroLayout: heroLayout,
            showSubThumbnail: showSubThumbnail
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        renderedShareImage = renderer.uiImage
    }
}

extension VisitSharePreviewSheet {
    func editableMapThumbnail(image: UIImage) -> some View {
        Sharing.editableMapThumbnail(image: image) { showMapEditor = true }
    }
}

// MARK: - 地図エディターシート

struct ShareMapEditorSheet: View {
    let spots: [CourseSpot]
    let visitCoordinate: CLLocationCoordinate2D?
    let initialRegion: MKCoordinateRegion
    let onConfirm: (UIImage) -> Void

    @State private var cameraPosition: MapCameraPosition
    @State private var currentRegion: MKCoordinateRegion
    @State private var isCapturing = false
    @Environment(\.dismiss) private var dismiss

    // コース/スポット用
    init(spots: [CourseSpot], initialRegion: MKCoordinateRegion, onConfirm: @escaping (UIImage) -> Void) {
        self.spots = spots
        self.visitCoordinate = nil
        self.initialRegion = initialRegion
        self.onConfirm = onConfirm
        _cameraPosition = State(initialValue: .region(initialRegion))
        _currentRegion = State(initialValue: initialRegion)
    }

    // 訪問記録用
    init(visitCoordinate: CLLocationCoordinate2D, initialRegion: MKCoordinateRegion, onConfirm: @escaping (UIImage) -> Void) {
        self.spots = []
        self.visitCoordinate = visitCoordinate
        self.initialRegion = initialRegion
        self.onConfirm = onConfirm
        _cameraPosition = State(initialValue: .region(initialRegion))
        _currentRegion = State(initialValue: initialRegion)
    }

    var body: some View {
        NavigationStack {
            Map(position: $cameraPosition) {
                ForEach(spots, id: \.id) { spot in
                    if spot.hasValidCoordinate {
                        Annotation(
                            "",
                            coordinate: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude),
                            anchor: .bottom
                        ) {
                            ShareMapPinView()
                        }
                    }
                }
                if let coord = visitCoordinate {
                    Marker("", coordinate: coord)
                        .tint(.blue)
                }
            }
            .mapStyle(.standard(emphasis: .muted))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange(frequency: .onEnd) { ctx in
                currentRegion = ctx.region
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(L.Share.mapEditorTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.Common.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isCapturing {
                        ProgressView().controlSize(.small)
                    } else {
                        Button(L.Common.done) {
                            Task { await captureAndConfirm() }
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private func captureAndConfirm() async {
        isCapturing = true
        let orderMap = Dictionary(uniqueKeysWithValues: spots.enumerated().map { ($0.offset, $0.offset + 1) })
        if let image = await makeShareMapSnapshot(region: currentRegion, spots: spots, orderNumbers: orderMap, pinCoordinate: visitCoordinate) {
            onConfirm(image)
        }
        dismiss()
    }
}

// MARK: - 地図エディター用ピンビュー（近くモードの任意ピンと同デザイン）

private struct ShareMapPinView: View {
    var body: some View {
        Image(systemName: "mappin")
            .font(.system(size: 28))
            .foregroundStyle(.indigo)
            .shadow(radius: 3)
    }
}

// MARK: - App Store バッジビュー

/// Assets.xcassets に "badge_app_store" という名前で公式バッジ画像を追加すると自動的に使用される。
/// 画像が未登録の場合はコードで再現したバッジを表示する。
private struct AppStoreBadgeView: View {
    var body: some View {
        if UIImage(named: "badge_app_store") != nil {
            Image("badge_app_store")
                .resizable()
                .scaledToFit()
                .frame(height: 30)
        } else {
            HStack(spacing: 5) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 18, weight: .regular))
                VStack(alignment: .leading, spacing: 0) {
                    Text("Download on the")
                        .font(.system(size: 7.5, weight: .regular))
                    Text("App Store")
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

// MARK: - 共有地図スナップショット生成（ファイルスコープ）

/// 指定リージョンの地図スナップショットを生成し、SpotPinView スタイルのピンを描画して返す
private func makeShareMapSnapshot(
    region: MKCoordinateRegion,
    spots: [CourseSpot],
    orderNumbers: [Int: Int],
    pinCoordinate: CLLocationCoordinate2D? = nil,
    pinColor: UIColor = .systemBlue
) async -> UIImage? {
    let options = MKMapSnapshotter.Options()
    options.region = region
    options.size = CGSize(width: SpotShareCard.cardWidth, height: 200)
    options.scale = UIScreen.main.scale
    options.mapType = .standard
    options.showsBuildings = true
    guard let snapshot = try? await MKMapSnapshotter(options: options).start() else { return nil }
    let size = options.size
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { _ in
        snapshot.image.draw(at: .zero)
        // コーススポットのピン
        for (_, spot) in spots.enumerated() {
            guard spot.hasValidCoordinate else { continue }
            let coord = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
            let point = snapshot.point(for: coord)
            guard point.x >= 0, point.x <= size.width,
                  point.y >= 0, point.y <= size.height else { continue }
            drawSpotPin(at: point)
        }
        // 単一座標ピン（訪問記録共有・達成スポット共有用）
        if let coord = pinCoordinate {
            let point = snapshot.point(for: coord)
            if point.x >= 0, point.x <= size.width,
               point.y >= 0, point.y <= size.height {
                drawSpotPin(at: point, color: pinColor)
            }
        }
    }
}

/// 近くモードの任意ピンと同デザインの mappin SF Symbol を描画する
private func drawSpotPin(at point: CGPoint, color: UIColor = .systemIndigo) {
    let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .regular)
    guard let pinImage = UIImage(systemName: "mappin", withConfiguration: config)?
        .withTintColor(color, renderingMode: .alwaysOriginal) else { return }
    let pinSize = pinImage.size
    guard let ctx = UIGraphicsGetCurrentContext() else { return }
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 2), blur: 4,
                  color: UIColor.black.withAlphaComponent(0.35).cgColor)
    // mappin の先端(下端中央)が point に来るよう配置
    pinImage.draw(in: CGRect(
        x: point.x - pinSize.width / 2,
        y: point.y - pinSize.height,
        width: pinSize.width,
        height: pinSize.height
    ))
    ctx.restoreGState()
}

// MARK: - 全スポットを収めるリージョン計算

private func spotsFitRegion(_ spots: [CourseSpot]) -> MKCoordinateRegion {
    let valid = spots.filter { $0.hasValidCoordinate }
    guard !valid.isEmpty else {
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 36.5, longitude: 136.0),
            span: MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 10.0)
        )
    }
    guard valid.count > 1 else {
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: valid[0].latitude, longitude: valid[0].longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
    }
    let lats = valid.map { $0.latitude }
    let lons = valid.map { $0.longitude }
    let centerLat = (lats.min()! + lats.max()!) / 2
    let centerLon = (lons.min()! + lons.max()!) / 2
    let spanLat = max((lats.max()! - lats.min()!) * 1.6, 0.01)
    let spanLon = max((lons.max()! - lons.min()!) * 1.6, 0.01)
    return MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
        span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
    )
}

// MARK: - UIActivityViewController を直接 present するヘルパー

/// SwiftUI の .sheet 経由では二重シート競合が発生するため、UIKit レイヤーで直接 present する
private func presentShareSheet(_ items: [Any]) {
    let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
    vc.excludedActivityTypes = [.assignToContact, .print, .saveToCameraRoll, .addToReadingList]

    guard let scene = UIApplication.shared.connectedScenes
        .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
          let window = scene.windows.first(where: { $0.isKeyWindow }) else { return }

    if let popover = vc.popoverPresentationController {
        popover.sourceView = window
        popover.sourceRect = CGRect(
            x: window.bounds.midX, y: window.bounds.midY,
            width: 0, height: 0
        )
        popover.permittedArrowDirections = []
    }

    var topVC = window.rootViewController
    while let presented = topVC?.presentedViewController {
        topVC = presented
    }
    topVC?.present(vc, animated: true)
}
