import SwiftUI

/// 初回起動時に表示するオンボーディング（3ページ構成）
/// - ページ1: 聖地巡礼モードの紹介（実際のアプリ画面の録画）
/// - ページ2: 記録モードの紹介（実際のアプリ画面の録画）
/// - ページ3: 位置情報の使用中の許可と、匿名データ送信の設定
/// 「常に許可」はここでは扱わない（自動記録をONにした時点で説明してからリクエストする）
struct OnboardingScreen: View {
    @Environment(AppModeManager.self) private var modeManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var store: OnboardingStore

    /// - Parameter store: 省略時は実アプリ用の依存関係で生成する（Preview では `.preview()` を渡す）
    /// デフォルト引数は呼び出し側の（非隔離の）コンテキストで評価されるため、
    /// MainActor 隔離の `live()` は init 本体の中で呼ぶ
    @MainActor
    init(store: OnboardingStore? = nil) {
        _store = State(initialValue: store ?? .live())
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $store.currentPage) {
                pilgrimagePage
                    .tag(OnboardingPage.pilgrimage)
                recordPage
                    .tag(OnboardingPage.record)
                locationPage
                    .tag(OnboardingPage.location)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .background(alignment: .top) {
                textAreaMeasurement
            }
            // 計測が済むまでは表示しない（初回フレームで文言の位置が跳ねるのを防ぐ）
            .opacity(introTextAreaHeight > 0 ? 1 : 0)

            footer
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .task {
            store.startPreparation()
        }
    }

    // MARK: - テキスト領域の高さの計測

    /// ページ1・2共通のテキスト領域の高さ（2ページのテキストのうち高い方）
    /// ページ3は匿名データの行がある分テキストが長いため、そろえずに自身の高さでレイアウトする
    /// （そろえるとページ1・2の動画が小さくなり、文言の下に間延びした余白ができるため）
    @State private var introTextAreaHeight: CGFloat = 0

    /// ページ1・2のテキストを非表示のまま重ねて、高い方の高さを測る。
    /// ページ送りの TabView は隣のページを後から生成することがあり、各ページで個別に測ると
    /// スワイプの途中で高さが変わって文言が動いてしまうため、画面側でまとめて測る。
    /// 幅は OnboardingPageLayout のテキスト幅（左右の余白・最大幅）と一致させる
    private var textAreaMeasurement: some View {
        ZStack(alignment: .top) {
            textBlock(for: .pilgrimage)
            textBlock(for: .record)
        }
        .padding(.horizontal, OnboardingLayout.horizontalPadding)
        .frame(maxWidth: OnboardingLayout.maxContentWidth)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            introTextAreaHeight = height
        }
        .hidden()
        .accessibilityHidden(true)
    }

    // MARK: - ページ

    @ViewBuilder
    private func textBlock(for page: OnboardingPage) -> some View {
        switch page {
        case .pilgrimage:
            OnboardingTextBlock(
                eyebrow: L.Onboarding.pilgrimageEyebrow,
                title: L.Onboarding.pilgrimageTitle,
                message: L.Onboarding.pilgrimageBody
            )
        case .record:
            OnboardingTextBlock(
                eyebrow: L.Onboarding.recordEyebrow,
                title: L.Onboarding.recordTitle,
                message: L.Onboarding.recordBody
            )
        case .location:
            OnboardingTextBlock(
                eyebrow: L.Onboarding.locationEyebrow,
                title: L.Onboarding.locationTitle,
                message: L.Onboarding.locationBody
            ) {
                OnboardingAnonymousDataRow()
            }
        }
    }

    private var pilgrimagePage: some View {
        OnboardingPageLayout(textAreaHeight: introTextAreaHeight) { maxSize in
            OnboardingMediaCard(media: .pilgrimage, isActive: isVisible(.pilgrimage), maxSize: maxSize)
        } text: {
            textBlock(for: .pilgrimage)
        }
    }

    private var recordPage: some View {
        OnboardingPageLayout(textAreaHeight: introTextAreaHeight) { maxSize in
            OnboardingMediaCard(media: .record, isActive: isVisible(.record), maxSize: maxSize)
        } text: {
            textBlock(for: .record)
        }
    }

    private var locationPage: some View {
        OnboardingPageLayout(visualAlignment: .center) { _ in
            OnboardingLocationVisual()
        } text: {
            textBlock(for: .location)
        }
    }

    /// 動画はページが表示されていて、かつアプリが前面にある間だけ再生する
    private func isVisible(_ page: OnboardingPage) -> Bool {
        store.currentPage == page && scenePhase == .active
    }

    // MARK: - フッター（ページインジケーター＋メインボタン）

    private var footer: some View {
        VStack(spacing: 24) {
            OnboardingPageIndicator(currentPage: $store.currentPage)

            if store.currentPage == .location {
                allowLocationButton
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        store.goToNextPage()
                    }
                } label: {
                    Text(L.Onboarding.next)
                }
                .buttonStyle(OnboardingPrimaryButtonStyle())
            }
        }
        .padding(.horizontal, OnboardingLayout.horizontalPadding)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .frame(maxWidth: OnboardingLayout.maxContentWidth)
    }

    /// ページ3のボタン。準備処理中・許可ダイアログへの回答待ちの間は無効にして小さな ProgressView を出す
    private var allowLocationButton: some View {
        let isBusy = store.isPreparing || store.isRequestingPermission
        return Button {
            store.requestPermissionAndFinish {
                modeManager.markWelcomeSeen()
            }
        } label: {
            HStack(spacing: 8) {
                if isBusy {
                    ProgressView()
                        .tint(.white)
                        .accessibilityLabel(L.Onboarding.preparing)
                }
                Text(L.Onboarding.allowLocationButton)
            }
        }
        .buttonStyle(OnboardingPrimaryButtonStyle())
        .disabled(isBusy)
    }
}

// MARK: - Preview

private extension View {
    /// プレビュー用に AppModeManager を差し込む（実際の UserDefaults を汚さない）
    func onboardingPreviewEnvironment() -> some View {
        environment(AppModeManager(defaults: UserDefaults(suiteName: "onboarding.preview") ?? .standard))
    }
}

#Preview("ページ1") {
    OnboardingScreen(store: .preview(initialPage: .pilgrimage))
        .onboardingPreviewEnvironment()
}

#Preview("ページ2") {
    OnboardingScreen(store: .preview(initialPage: .record))
        .onboardingPreviewEnvironment()
}

#Preview("ページ3") {
    OnboardingScreen(store: .preview(initialPage: .location))
        .onboardingPreviewEnvironment()
}

#Preview("ダークモード") {
    OnboardingScreen(store: .preview(initialPage: .location))
        .onboardingPreviewEnvironment()
        .preferredColorScheme(.dark)
}

#Preview("最大文字サイズ") {
    OnboardingScreen(store: .preview(initialPage: .pilgrimage))
        .onboardingPreviewEnvironment()
        .environment(\.dynamicTypeSize, .accessibility5)
}
