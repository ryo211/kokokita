import SwiftUI

/// UI全体で使用する定数（スペーシング、サイズ、パディング、角丸など）
enum UIConstants {

    // MARK: - Spacing
    /// 標準的な間隔の定義
    enum Spacing {
        static let extraSmall: CGFloat = 2
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let extraLarge: CGFloat = 16
        static let xxLarge: CGFloat = 20
    }

    // MARK: - Size
    /// 標準的なサイズの定義
    enum Size {
        /// タブバーの高さ
        static let tabBarHeight: CGFloat = 72
        /// タブバー中央ボタンのサイズ
        static let centerButtonSize: CGFloat = 64
        /// 地図プレビューの高さ
        static let mapPreviewHeight: CGFloat = 220
        /// 共有用地図の高さ
        static let shareMapHeight: CGFloat = 300
        /// 写真サムネイルのサイズ
        static let photoThumbnail: CGFloat = 64
    }

    // MARK: - Padding
    /// 各コンポーネントのパディング
    enum Padding {
        /// チップ（通常サイズ）のパディング
        static let chipVertical: CGFloat = 6
        static let chipHorizontal: CGFloat = 10

        /// チップ（小サイズ）のパディング
        static let chipSmallVertical: CGFloat = 3
        static let chipSmallHorizontal: CGFloat = 6

        /// InfoCardのデフォルトパディング
        static let infoCard: CGFloat = 16

        /// 画面横方向の標準パディング
        static let screenHorizontal: CGFloat = 16
    }

    // MARK: - Corner Radius
    /// 角丸の半径
    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 20

        /// チップの角丸
        static let chip: CGFloat = 16
    }

    // MARK: - Alpha (Opacity)
    /// 透明度の定義
    enum Alpha {
        /// 微妙なハイライト
        static let subtleHighlight: Double = 0.06
        /// チップの背景
        static let chipBackground: Double = 0.15
        /// 軽い影
        static let shadowLight: Double = 0.06
        /// 中程度の影
        static let shadowMedium: Double = 0.15
        /// 濃い影
        static let shadowDark: Double = 0.25
        /// バッジ背景
        static let badgeBackground: Double = 0.7
        /// システム背景（半透明）
        static let systemBackgroundSemi: Double = 0.8
    }

    // MARK: - Shadow
    /// 影の設定
    enum Shadow {
        static let radiusSmall: CGFloat = 1
        static let radiusMedium: CGFloat = 2
        static let radiusLarge: CGFloat = 8
        static let offsetY: CGFloat = 1
        static let offsetYLarge: CGFloat = 4
    }

    // MARK: - Animation
    /// アニメーション設定
    enum Animation {
        /// 検索フィルターのデバウンス時間（ナノ秒）
        static let searchDebounceNanoseconds: UInt64 = 250_000_000
    }
}
