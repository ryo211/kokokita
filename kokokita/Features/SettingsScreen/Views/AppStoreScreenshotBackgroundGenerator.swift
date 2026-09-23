import SwiftUI
import UIKit

// App Storeスクリーンショット用の背景（コースカードをカードゲームのコレクション画面のように
// 散らして配置したもの）を生成する開発者機能。実機フレームやキャッチコピーは対象外で、
// 既存のスクショ制作フローに差し込む「背景画像だけ」をPNGで書き出す。
#if DEBUG
struct AppStoreScreenshotBackgroundGenerator: View {
    private enum ExportSize: String, CaseIterable, Identifiable {
        case size69
        case size65

        var id: String { rawValue }

        var title: String {
            switch self {
            case .size69: return "6.9インチ (1320×2868)"
            case .size65: return "6.5インチ (1284×2778)"
            }
        }

        var pixelSize: CGSize {
            switch self {
            case .size69: return CGSize(width: 1320, height: 2868)
            case .size65: return CGSize(width: 1284, height: 2778)
            }
        }
    }

    @State private var seed: UInt64 = 20250128
    @State private var cardCount: Double = 14
    @State private var exportSize: ExportSize = .size69
    @State private var coursePage: Int = 1
    @State private var allCourses: [Course] = []
    @State private var loadedImages: [UUID: UIImage] = [:]
    @State private var isLoadingImages = false
    @State private var renderedShareItem: RenderedScreenshotBackground?
    @State private var alert: AlertMessage?

    private var eligibleCourses: [Course] {
        allCourses.filter { $0.localCoverImagePath != nil || $0.coverImageUrl != nil }
    }

    // コースをカード枚数ごとに区切ったときの総ページ数。ページを進めるたびに
    // 全く別のコースの組み合わせで背景を作れるようにする
    private var maxCoursePage: Int {
        let count = eligibleCourses.count
        guard count > 0, cardCount > 0 else { return 1 }
        return max(1, Int(ceil(Double(count) / cardCount)))
    }

    // 現在のページの開始位置から並べ直したコース一覧。先頭からcardCount枚を
    // 使うだけで、ページごとに全く別の組み合わせになる
    private var pagedCourses: [Course] {
        let courses = eligibleCourses
        guard !courses.isEmpty else { return [] }
        let startIndex = ((coursePage - 1) * Int(cardCount)) % courses.count
        return Array(courses[startIndex...] + courses[..<startIndex])
    }

    private var previewSize: CGSize {
        let width: CGFloat = 220
        let ratio = exportSize.pixelSize.height / exportSize.pixelSize.width
        return CGSize(width: width, height: width * ratio)
    }

    var body: some View {
        List {
            Section {
                Group {
                    if isLoadingImages {
                        ProgressView()
                            .frame(width: previewSize.width, height: previewSize.height)
                    } else {
                        ScreenshotBackgroundCanvas(
                            courses: pagedCourses,
                            images: loadedImages,
                            seed: seed,
                            cardCount: Int(cardCount),
                            size: previewSize
                        )
                        .frame(width: previewSize.width, height: previewSize.height)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 6)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            } header: {
                Text("Preview")
            } footer: {
                Text("背景のみのPNGです。実機フレームやキャッチコピーは別途重ねてください。")
            }

            Section {
                Button {
                    withAnimation(.snappy) {
                        seed = UInt64.random(in: UInt64.min...UInt64.max)
                    }
                } label: {
                    Label("模様を変える", systemImage: "shuffle")
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("カード枚数")
                        Spacer()
                        Text("\(Int(cardCount))枚")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $cardCount, in: 6...24, step: 1)
                }

                Picker("書き出しサイズ", selection: $exportSize) {
                    ForEach(ExportSize.allCases) { size in
                        Text(size.title).tag(size)
                    }
                }

                Stepper(value: $coursePage, in: 1...maxCoursePage) {
                    HStack {
                        Text("コースページ")
                        Spacer()
                        Text("\(coursePage) / \(maxCoursePage)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("使用中の全コースを作成日順に並べ、カード枚数ごとに区切って使います。ページを進めると別のコースの組み合わせになります。")
            }

            Section {
                Button {
                    renderAndExport()
                } label: {
                    Label("PNGを書き出す", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .disabled(isLoadingImages || eligibleCourses.isEmpty)
            }
        }
        .navigationTitle("Screenshot Background")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadCourses()
        }
        .sheet(item: $renderedShareItem) { item in
            ShareSheet(items: [item.url])
        }
        .alert(item: $alert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    @MainActor
    private func loadCourses() async {
        do {
            allCourses = try AppContainer.shared.courseRepo.fetchAll()
        } catch {
            alert = AlertMessage(title: "読み込み失敗", message: error.localizedDescription)
            return
        }
        isLoadingImages = true
        defer { isLoadingImages = false }
        for course in eligibleCourses {
            if let image = await CourseSlideShowImageCache.shared.image(for: course) {
                loadedImages[course.id] = image
            }
        }
    }

    @MainActor
    private func renderAndExport() {
        let size = exportSize.pixelSize
        let content = ScreenshotBackgroundCanvas(
            courses: pagedCourses,
            images: loadedImages,
            seed: seed,
            cardCount: Int(cardCount),
            size: size
        )
        .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        renderer.isOpaque = true
        guard let uiImage = renderer.uiImage, let data = uiImage.pngData() else {
            alert = AlertMessage(title: "書き出し失敗", message: "画像を生成できませんでした。")
            return
        }
        do {
            let filename = "kokokita-screenshot-bg-\(exportSize.rawValue)-page\(coursePage)-seed\(seed).png"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
            renderedShareItem = RenderedScreenshotBackground(url: url)
        } catch {
            alert = AlertMessage(title: "保存失敗", message: error.localizedDescription)
        }
    }
}

private struct RenderedScreenshotBackground: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - 背景キャンバス（カード散らし配置）

private struct ScreenshotBackgroundCanvas: View {
    let courses: [Course]
    let images: [UUID: UIImage]
    let seed: UInt64
    let cardCount: Int
    let size: CGSize

    private struct Placement {
        let course: Course
        let x: CGFloat
        let y: CGFloat
        let cellWidth: CGFloat
        let scale: CGFloat
    }

    // グリッドに沿って等間隔に並べた上で、セル内だけの小さなジッターと
    // カードごとの大きさのばらつきを与える。角度は付けず、偏りの出やすい
    // 自由配置はやめて整頓感を優先する
    private var cardPlacements: [Placement] {
        guard !courses.isEmpty, cardCount > 0 else { return [] }
        var rng = SeededRandom(state: seed)

        let canvasAspect = size.width / size.height
        let columns = min(5, max(3, Int(ceil(sqrt(Double(cardCount) * canvasAspect)))))
        let rows = Int(ceil(Double(cardCount) / Double(columns)))
        let cellWidth = size.width / CGFloat(columns)
        let cellHeight = size.height / CGFloat(rows)

        var placements: [Placement] = []
        for i in 0..<cardCount {
            let course = courses[i % courses.count]
            let col = i % columns
            let row = i / columns
            let centerX = cellWidth * (CGFloat(col) + 0.5)
            let centerY = cellHeight * (CGFloat(row) + 0.5)
            let jitterX = rng.nextCGFloat(in: -cellWidth * 0.12...cellWidth * 0.12)
            let jitterY = rng.nextCGFloat(in: -cellHeight * 0.12...cellHeight * 0.12)
            let scale = rng.nextCGFloat(in: 0.68...1.32)
            placements.append(
                Placement(
                    course: course,
                    x: centerX + jitterX,
                    y: centerY + jitterY,
                    cellWidth: cellWidth,
                    scale: scale
                )
            )
        }

        // 描画順(=手前/奥の重なり順)を位置と無関係にシャッフルする。
        // 行・列の順で描画すると「右側や下側の行が必ず手前に来る」という
        // 機械的な重なりに見えてしまうため、シード付きで並び替えて崩す
        for i in stride(from: placements.count - 1, to: 0, by: -1) {
            let j = Int(rng.next() % UInt64(i + 1))
            placements.swapAt(i, j)
        }

        return placements
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.06, blue: 0.16),
                    Color(red: 0.12, green: 0.10, blue: 0.26)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            ForEach(Array(cardPlacements.enumerated()), id: \.offset) { _, placement in
                if let image = images[placement.course.id] {
                    ScreenshotCollectionCard(course: placement.course, image: image, width: placement.cellWidth * 0.86)
                        .frame(width: placement.cellWidth * 0.86)
                        .scaleEffect(placement.scale)
                        .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 8)
                        .position(x: placement.x, y: placement.y)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}

// MARK: - コレクションカード

private struct ScreenshotCollectionCard: View {
    let course: Course
    let image: UIImage
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()

            LinearGradient(
                colors: [.clear, .black.opacity(0.15), .black.opacity(0.82)],
                startPoint: .center,
                endPoint: .bottom
            )

            Text(course.title)
                .font(.system(size: width * 0.115, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
                .padding(width * 0.09)
        }
        .aspectRatio(0.68, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: width * 0.05, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: width * 0.05, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.95), Color.white.opacity(0.45)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(1, width * 0.013)
                )
        }
    }
}
#endif
