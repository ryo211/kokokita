import SwiftUI
import UIKit

#if DEBUG
struct AppIconGeneratorScreen: View {
    @State private var selectedAppearance: AppIconAppearance = .light
    @State private var selectedVariant: AppIconVariant = .clearBlueDeep
    @State private var logoScaleAdjustment: Double = 1.0
    @State private var renderedShareItem: RenderedAppIcon?
    @State private var alert: AlertMessage?

    var body: some View {
        List {
            Section {
                VStack(spacing: 18) {
                    AppIconCanvas(
                        appearance: selectedAppearance,
                        variant: selectedVariant,
                        size: 220,
                        logoScaleAdjustment: logoScaleAdjustment
                    )
                        .frame(width: 220, height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 48, style: .continuous))
                        .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 8)
                        .padding(.top, 10)

                    VStack(spacing: 4) {
                        Text("\(selectedAppearance.title) / \(selectedVariant.title)")
                            .font(.headline)
                        Text(selectedVariant.description(for: selectedAppearance))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Text("Logo \(Int(logoScaleAdjustment * 100))%")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 18, trailing: 16))
            } header: {
                Text("Preview")
            } footer: {
                Text("書き出し画像は1024x1024 PNGです。XcodeのAppIconに登録する前提なので、文字は入れずロゴを大きめにしています。")
            }

            Section {
                Picker("Appearance", selection: $selectedAppearance) {
                    ForEach(AppIconAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("Dark / Tinted はXcodeのAppIconに対応スロットを用意した場合の候補です。Tintedはホーム画面の色調変更に馴染みやすいよう、控えめで単色寄りにしています。")
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("ロゴサイズ")
                        Spacer()
                        Text("\(Int(logoScaleAdjustment * 100))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $logoScaleAdjustment, in: 0.9...1.22, step: 0.01)
                }

                Button {
                    withAnimation(.snappy) {
                        logoScaleAdjustment = 1.0
                    }
                } label: {
                    Label("標準サイズに戻す", systemImage: "arrow.counterclockwise")
                }
            } footer: {
                Text("プレビューとPNG書き出しの両方に反映されます。")
            }

            Section {
                ForEach(AppIconVariant.allCases) { variant in
                    Button {
                        withAnimation(.snappy) {
                            selectedVariant = variant
                        }
                    } label: {
                        HStack(spacing: 12) {
                            AppIconCanvas(
                                appearance: selectedAppearance,
                                variant: variant,
                                size: 52,
                                logoScaleAdjustment: logoScaleAdjustment
                            )
                                .frame(width: 52, height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(variant.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(variant.description(for: selectedAppearance))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if selectedVariant == variant {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.indigo)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Variants")
            }

            Section {
                Button {
                    renderSelectedIcon()
                } label: {
                    Label("PNGを書き出す", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
            } footer: {
                Text("共有シートから画像保存、AirDrop、Files保存などを選べます。")
            }
        }
        .navigationTitle("App Icon Generator")
        .navigationBarTitleDisplayMode(.inline)
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
    private func renderSelectedIcon() {
        guard let image = renderIcon(
            appearance: selectedAppearance,
            variant: selectedVariant,
            logoScaleAdjustment: logoScaleAdjustment
        ) else {
            alert = AlertMessage(title: "書き出し失敗", message: "アイコン画像を生成できませんでした。")
            return
        }

        guard let data = image.pngData() else {
            alert = AlertMessage(title: "書き出し失敗", message: "PNGデータを作成できませんでした。")
            return
        }

        do {
            let logoPercent = Int(logoScaleAdjustment * 100)
            let filename = "kokokita-app-icon-\(selectedAppearance.rawValue)-\(selectedVariant.rawValue)-logo\(logoPercent).png"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
            renderedShareItem = RenderedAppIcon(url: url)
        } catch {
            alert = AlertMessage(title: "保存失敗", message: error.localizedDescription)
        }
    }

    @MainActor
    private func renderIcon(
        appearance: AppIconAppearance,
        variant: AppIconVariant,
        logoScaleAdjustment: Double
    ) -> UIImage? {
        let content = AppIconCanvas(
            appearance: appearance,
            variant: variant,
            size: 1024,
            logoScaleAdjustment: logoScaleAdjustment
        )
            .frame(width: 1024, height: 1024)
            .environment(\.colorScheme, appearance == .dark ? .dark : .light)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

private struct RenderedAppIcon: Identifiable {
    let id = UUID()
    let url: URL
}

private enum AppIconAppearance: String, CaseIterable, Identifiable {
    case light
    case dark
    case tinted

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .tinted: return "Tinted"
        }
    }
}

private enum AppIconVariant: String, CaseIterable, Identifiable {
    case clearBlue
    case clearBlueBright
    case clearBlueDeep
    case clearBlueAqua

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clearBlue: return "Clear Blue"
        case .clearBlueBright: return "Clear Blue Bright"
        case .clearBlueDeep: return "Clear Blue Deep"
        case .clearBlueAqua: return "Clear Blue Aqua"
        }
    }

    func description(for appearance: AppIconAppearance) -> String {
        switch appearance {
        case .light:
            switch self {
            case .clearBlue: return "標準案。青の透明感とロゴの見やすさをバランス"
            case .clearBlueBright: return "明るめ。ホーム画面で軽く爽やかに見える案"
            case .clearBlueDeep: return "採用案。控えめなガラス感でタブバーのボタンに近い案"
            case .clearBlueAqua: return "さらに淡いガラス感。ロゴを主役にした案"
            }
        case .dark:
            switch self {
            case .clearBlue: return "白寄りロゴを深いネイビーに浮かせる案"
            case .clearBlueBright: return "ロゴ周辺に明るい発光感を足す案"
            case .clearBlueDeep: return "暗い背景を控えめにしてロゴを最優先する案"
            case .clearBlueAqua: return "青緑の光で輪郭を読みやすくする案"
            }
        case .tinted:
            switch self {
            case .clearBlue: return "単色化されても形が読みやすい標準案"
            case .clearBlueBright: return "明るい淡色ベースで軽い案"
            case .clearBlueDeep: return "採用案に近い控えめ背景のTinted版"
            case .clearBlueAqua: return "最も淡く、ロゴのシルエットを優先した案"
            }
        }
    }

    var logoName: String {
        "kokokita_irodori_blue_v2"
    }

    func primary(for appearance: AppIconAppearance) -> Color {
        switch appearance {
        case .light:
            switch self {
            case .clearBlue: return Color(red: 0.10, green: 0.43, blue: 0.96)
            case .clearBlueBright: return Color(red: 0.08, green: 0.54, blue: 1.0)
            case .clearBlueDeep: return Color(red: 0.70, green: 0.86, blue: 1.0)
            case .clearBlueAqua: return Color(red: 0.82, green: 0.93, blue: 1.0)
            }
        case .dark:
            switch self {
            case .clearBlue: return Color(red: 0.025, green: 0.045, blue: 0.14)
            case .clearBlueBright: return Color(red: 0.035, green: 0.07, blue: 0.20)
            case .clearBlueDeep: return Color(red: 0.018, green: 0.030, blue: 0.10)
            case .clearBlueAqua: return Color(red: 0.018, green: 0.075, blue: 0.13)
            }
        case .tinted:
            switch self {
            case .clearBlue: return Color(red: 0.70, green: 0.82, blue: 0.92)
            case .clearBlueBright: return Color(red: 0.82, green: 0.90, blue: 0.96)
            case .clearBlueDeep: return Color(red: 0.74, green: 0.84, blue: 0.92)
            case .clearBlueAqua: return Color(red: 0.88, green: 0.94, blue: 0.96)
            }
        }
    }

    func secondary(for appearance: AppIconAppearance) -> Color {
        switch appearance {
        case .light:
            switch self {
            case .clearBlue: return Color(red: 0.28, green: 0.78, blue: 0.98)
            case .clearBlueBright: return Color(red: 0.44, green: 0.86, blue: 1.0)
            case .clearBlueDeep: return Color(red: 0.94, green: 0.98, blue: 1.0)
            case .clearBlueAqua: return Color(red: 0.98, green: 1.0, blue: 1.0)
            }
        case .dark:
            switch self {
            case .clearBlue: return Color(red: 0.12, green: 0.24, blue: 0.50)
            case .clearBlueBright: return Color(red: 0.18, green: 0.40, blue: 0.78)
            case .clearBlueDeep: return Color(red: 0.10, green: 0.16, blue: 0.36)
            case .clearBlueAqua: return Color(red: 0.08, green: 0.38, blue: 0.45)
            }
        case .tinted:
            switch self {
            case .clearBlue: return Color(red: 0.94, green: 0.97, blue: 1.0)
            case .clearBlueBright: return Color(red: 0.98, green: 1.0, blue: 1.0)
            case .clearBlueDeep: return Color(red: 0.90, green: 0.95, blue: 0.99)
            case .clearBlueAqua: return Color.white
            }
        }
    }

    func accent(for appearance: AppIconAppearance) -> Color {
        switch appearance {
        case .light:
            switch self {
            case .clearBlue: return Color(red: 0.86, green: 0.96, blue: 1.0)
            case .clearBlueBright: return Color(red: 0.92, green: 0.98, blue: 1.0)
            case .clearBlueDeep: return Color.white
            case .clearBlueAqua: return Color(red: 0.94, green: 0.99, blue: 1.0)
            }
        case .dark:
            switch self {
            case .clearBlue: return Color(red: 0.72, green: 0.88, blue: 1.0)
            case .clearBlueBright: return Color(red: 0.82, green: 0.94, blue: 1.0)
            case .clearBlueDeep: return Color(red: 0.70, green: 0.82, blue: 1.0)
            case .clearBlueAqua: return Color(red: 0.62, green: 0.98, blue: 0.96)
            }
        case .tinted:
            switch self {
            case .clearBlue: return Color.white
            case .clearBlueBright: return Color.white
            case .clearBlueDeep: return Color(red: 0.97, green: 0.99, blue: 1.0)
            case .clearBlueAqua: return Color.white
            }
        }
    }

    var logoScale: CGFloat {
        switch self {
        case .clearBlue: return 0.72
        case .clearBlueBright: return 0.74
        case .clearBlueDeep: return 0.74
        case .clearBlueAqua: return 0.76
        }
    }

    func highlightOpacity(for appearance: AppIconAppearance) -> Double {
        switch appearance {
        case .light:
            switch self {
            case .clearBlue: return 0.28
            case .clearBlueBright: return 0.34
            case .clearBlueDeep: return 0.18
            case .clearBlueAqua: return 0.16
            }
        case .dark:
            switch self {
            case .clearBlue: return 0.10
            case .clearBlueBright: return 0.16
            case .clearBlueDeep: return 0.08
            case .clearBlueAqua: return 0.12
            }
        case .tinted:
            switch self {
            case .clearBlue: return 0.18
            case .clearBlueBright: return 0.22
            case .clearBlueDeep: return 0.14
            case .clearBlueAqua: return 0.12
            }
        }
    }

    func sheenOpacity(for appearance: AppIconAppearance) -> Double {
        switch appearance {
        case .light:
            switch self {
            case .clearBlue, .clearBlueBright: return 1.0
            case .clearBlueDeep: return 0.55
            case .clearBlueAqua: return 0.42
            }
        case .dark:
            switch self {
            case .clearBlue: return 0.22
            case .clearBlueBright: return 0.30
            case .clearBlueDeep: return 0.18
            case .clearBlueAqua: return 0.24
            }
        case .tinted:
            switch self {
            case .clearBlue: return 0.26
            case .clearBlueBright: return 0.30
            case .clearBlueDeep: return 0.22
            case .clearBlueAqua: return 0.18
            }
        }
    }
}

private struct AppIconCanvas: View {
    let appearance: AppIconAppearance
    let variant: AppIconVariant
    let size: CGFloat
    let logoScaleAdjustment: Double

    private var logoSize: CGFloat {
        size * variant.logoScale * CGFloat(logoScaleAdjustment)
    }

    var body: some View {
        ZStack {
            background
            glassHighlights
            logo
            foregroundSheen
        }
        .frame(width: size, height: size)
        .saturation(appearance == .tinted ? 0.18 : 1.0)
        .contrast(appearance == .tinted ? 1.08 : 1.0)
    }

    private var background: some View {
        LinearGradient(
            colors: [
                variant.accent(for: appearance),
                variant.secondary(for: appearance),
                variant.primary(for: appearance)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var glassHighlights: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(variant.highlightOpacity(for: appearance)))
                .frame(width: size * 0.72, height: size * 0.72)
                .blur(radius: size * 0.07)
                .offset(x: -size * 0.28, y: -size * 0.30)

            Circle()
                .fill(variant.accent(for: appearance).opacity(appearance == .dark ? 0.16 : 0.24))
                .frame(width: size * 0.52, height: size * 0.52)
                .blur(radius: size * 0.08)
                .offset(x: size * 0.32, y: size * 0.26)

            LinearGradient(
                colors: [
                    .white.opacity(0.26),
                    .white.opacity(0.05),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var logo: some View {
        Image(variant.logoName)
            .resizable()
            .scaledToFit()
            .frame(width: logoSize, height: logoSize)
            .saturation(logoSaturation)
            .brightness(logoBrightness)
            .contrast(logoContrast)
            .shadow(color: .black.opacity(appearance == .dark ? 0.46 : 0.24), radius: size * 0.030, x: 0, y: size * 0.020)
            .shadow(color: variant.accent(for: appearance).opacity(appearance == .dark ? 0.62 : 0.24), radius: size * 0.040, x: 0, y: 0)
            .shadow(color: variant.accent(for: appearance).opacity(appearance == .dark ? 0.38 : 0.0), radius: size * 0.075, x: 0, y: 0)
    }

    private var logoSaturation: Double {
        switch appearance {
        case .light: return 1.0
        case .dark: return 0.20
        case .tinted: return 0.08
        }
    }

    private var logoBrightness: Double {
        switch appearance {
        case .light: return 0
        case .dark: return 0.26
        case .tinted: return 0
        }
    }

    private var logoContrast: Double {
        switch appearance {
        case .light: return 1.0
        case .dark: return 1.24
        case .tinted: return 1.15
        }
    }

    private var foregroundSheen: some View {
        LinearGradient(
            stops: [
                .init(color: .white.opacity(0.34), location: 0),
                .init(color: .white.opacity(0.10), location: 0.34),
                .init(color: .clear, location: 0.66)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .opacity(variant.sheenOpacity(for: appearance))
        .blendMode(.screen)
    }
}
#endif
