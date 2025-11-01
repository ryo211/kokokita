import SwiftUI

/// ホーム画面用のヘッダーロゴ
struct KokokitaHeaderLogo: View {
    var size: Size = .medium

    enum Size {
        case small
        case medium
        case large

        var iconSize: CGFloat {
            switch self {
            case .small: return 24
            case .medium: return 32
            case .large: return 40
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .small: return 18
            case .medium: return 24
            case .large: return 32
            }
        }

        var spacing: CGFloat {
            switch self {
            case .small: return 4
            case .medium: return 6
            case .large: return 8
            }
        }
        
        var opticalOffsetX: CGFloat {
            // 視覚中心（光学的な中心）補正：
            // カタカナの「コ」「タ」形状とピン記号の構成により、
            // 幾何学的中心よりもわずかに左に重心が見えるため、
            // 右方向に微小オフセットして見た目を中央に揃える。
            switch self {
            case .small:  return 1.0
            case .medium: return 1.5
            case .large:  return 2.0
            }
        }
    }

    var body: some View {
        HStack(spacing: size.spacing) {
            // アイコン部分
            Image("kokokita_irodori_blue")
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)

            // テキスト部分 - スマート＆おしゃれ
            Text("ココキタ")
                .font(.system(size: size.fontSize, weight: .semibold, design: .rounded))
                .tracking(1.2)  // 文字間隔を広げる
                .foregroundColor(.accentColor)
        }
        .offset(x: size.opticalOffsetX)
    }
}

/// ナビゲーションバー用のシンプルバージョン
struct KokokitaHeaderLogoSimple: View {
    var body: some View {
        HStack(spacing: 6) {
            // アイコン
            Image("kokokita_irodori_blue")
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)

            // テキスト - スマート＆おしゃれ
            Text("ココキタ")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .tracking(1.2)  // 文字間隔を広げる
                .foregroundColor(.accentColor)
        }
    }
}

#Preview("Medium") {
    VStack(spacing: 20) {
        KokokitaHeaderLogo(size: .small)
        KokokitaHeaderLogo(size: .medium)
        KokokitaHeaderLogo(size: .large)
        Divider()
        KokokitaHeaderLogoSimple()
    }
    .padding()
}
