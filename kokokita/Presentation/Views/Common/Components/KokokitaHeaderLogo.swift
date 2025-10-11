//
//  KokokitaHeaderLogo.swift
//  kokokita
//
//  Created by Claude on 2025/10/11.
//

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
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: size.iconSize, height: size.iconSize)

                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(.white)
                    .font(.system(size: size.iconSize * 0.5, weight: .semibold))
            }

            // テキスト部分 - スマート＆おしゃれ
            Text("ココキタ")
                .font(.system(size: size.fontSize, weight: .semibold, design: .rounded))
                .tracking(1.2)  // 文字間隔を広げる
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.75)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .offset(x: size.opticalOffsetX)
    }
}

/// ナビゲーションバー用のシンプルバージョン
struct KokokitaHeaderLogoSimple: View {
    var body: some View {
        HStack(spacing: 6) {
            // アイコン
            Image(systemName: "mappin.and.ellipse")
                .foregroundStyle(.white)
                .font(.callout.weight(.semibold))
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.accentColor))

            // テキスト - スマート＆おしゃれ
            Text("ココキタ")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .tracking(1.2)  // 文字間隔を広げる
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.95),
                            Color.accentColor.opacity(0.75)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.accentColor.opacity(0.2), radius: 2, x: 0, y: 1)
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
