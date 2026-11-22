import UIKit

/// オンボーディングのページ1・2に表示する録画素材の定義
///
/// 素材は `kokokita/Resources/Onboarding/` に置き、アプリのバンドルに同梱する。
/// 差し替えは同じファイル名で上書きするだけでよい（コードの変更は不要）。
/// - 動画: `<videoName>.mp4`（HEVC推奨、音声なし、ミュートでループ再生）
/// - 静止画: `<stillName>.jpg`（Reduce Motion 有効時に動画の代わりに表示。動画と同じ切り抜きの1コマ）
/// 英語版の素材を用意する場合は `en.lproj/` に同名のファイルを置けば自動で切り替わる。
/// ファイルが見つからない場合はプレースホルダーを表示する。
struct OnboardingMedia {
    /// 動画のファイル名（拡張子なし）
    let videoName: String
    /// 静止画のファイル名（拡張子なし）
    let stillName: String
    /// 素材の中で表示する範囲（左上原点、0〜1の正規化座標）
    /// 素材全体を表示するなら (0, 0, 1, 1)。上下の余白を削りたい場合などはここを調整する
    let cropRect: CGRect
    /// 静止画が無いときに使う素材の縦横比（幅 / 高さ）。静止画があればその実寸から求める
    let fallbackAspectRatio: CGFloat
    /// VoiceOver で読み上げる、素材の内容の説明
    let accessibilityLabel: String
    /// 素材が届くまでのプレースホルダーに表示する SF Symbol
    let placeholderSymbol: String

    static let videoExtension = "mp4"
    static let stillExtension = "jpg"

    var videoURL: URL? {
        Bundle.main.url(forResource: videoName, withExtension: Self.videoExtension)
    }

    /// 静止画（一度読み込んだらキャッシュする。View の再生成のたびにデコードしないため）
    var stillImage: UIImage? {
        if let cached = Self.stillImageCache[stillName] { return cached }
        let image = Bundle.main
            .url(forResource: stillName, withExtension: Self.stillExtension)
            .flatMap { UIImage(contentsOfFile: $0.path) }
        Self.stillImageCache[stillName] = .some(image)
        #if DEBUG
        if image == nil && videoURL == nil {
            Logger.warning("オンボーディング素材が見つかりません（プレースホルダーを表示）: \(videoName)")
        }
        #endif
        return image
    }

    /// 静止画のキャッシュ（読み込み失敗＝nil も記録して再試行しない）
    private static var stillImageCache: [String: UIImage?] = [:]
}

extension OnboardingMedia {
    /// ページ1: 聖地巡礼でスポットに到達し、スポットカード右のハンコが押される様子
    static let pilgrimage = OnboardingMedia(
        videoName: "onboarding_pilgrimage",
        stillName: "onboarding_pilgrimage_still",
        cropRect: CGRect(x: 0, y: 0, width: 1, height: 1),
        fallbackAspectRatio: 1080.0 / 1362.0,
        accessibilityLabel: L.Onboarding.pilgrimageMediaLabel,
        placeholderSymbol: "seal"
    )

    /// ページ2: 記録モードで現在地を記録したときの画面
    static let record = OnboardingMedia(
        videoName: "onboarding_record",
        stillName: "onboarding_record_still",
        cropRect: CGRect(x: 0, y: 0, width: 1, height: 1),
        fallbackAspectRatio: 1080.0 / 1362.0,
        accessibilityLabel: L.Onboarding.recordMediaLabel,
        placeholderSymbol: "mappin.and.ellipse"
    )
}
