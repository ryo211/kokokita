import SwiftUI
import AVFoundation

/// ミュート・ループ再生する動画ビュー（再生コントロールは表示しない）
/// `isPlaying` が false の間は一時停止する（ページを離れたとき・バックグラウンド時に止めるため）
struct LoopingVideoPlayerView: UIViewRepresentable {
    let url: URL
    let isPlaying: Bool

    func makeUIView(context: Context) -> LoopingPlayerUIView {
        LoopingPlayerUIView(url: url)
    }

    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {
        uiView.setPlaying(isPlaying)
    }

    static func dismantleUIView(_ uiView: LoopingPlayerUIView, coordinator: ()) {
        uiView.teardown()
    }
}

/// AVPlayerLayer をバッキングレイヤーに持つ UIView。AVPlayerLooper でシームレスにループさせる
final class LoopingPlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?

    init(url: URL) {
        super.init(frame: .zero)
        Self.configureAudioSessionIfNeeded()

        let player = AVQueuePlayer()
        player.isMuted = true
        // ループ動画のために画面のスリープを妨げない
        player.preventsDisplaySleepDuringVideoPlayback = false
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        playerLayer.player = player
        // 表示枠は素材と同じ縦横比にしてあるため、fill でも実質的に切れない（端数の隙間を出さないため fill にする）
        playerLayer.videoGravity = .resizeAspectFill
        self.player = player
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) は未対応です")
    }

    func setPlaying(_ playing: Bool) {
        guard let player else { return }
        if playing {
            if player.timeControlStatus != .playing { player.play() }
        } else {
            player.pause()
        }
    }

    func teardown() {
        player?.pause()
        looper?.disableLooping()
        looper = nil
        playerLayer.player = nil
        player = nil
    }

    /// ミュート動画の再生で、ユーザーが聴いている音楽などを止めないようにする
    /// （このアプリは他に音声を扱わないため、カテゴリを ambient にしても影響はない）
    private static var hasConfiguredAudioSession = false
    private static func configureAudioSessionIfNeeded() {
        guard !hasConfiguredAudioSession else { return }
        hasConfiguredAudioSession = true
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        } catch {
            Logger.warning("オーディオセッションの設定に失敗しました: \(error.localizedDescription)")
        }
    }
}
