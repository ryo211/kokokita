import SwiftUI

// 聖地巡礼モードの使い方シート
// 各ステップは タイトル・スクリーンショット（0枚以上）・説明・補足（任意）で構成
struct PilgrimageHowToUseSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let steps: [HowToUseStep] = [
        HowToUseStep(
            title: "コースを見て、行きたい場所を決める",
            imageNames: ["guide_1"],
            description: "コース一覧から行きたいコースを見つけましょう。\n行きたいコースがない場合は、右上の＋ボタンからコースを追加しましょう。",
            supplement: "コースは随時追加・更新していく予定です。お楽しみに！"
        ),
        HowToUseStep(
            title: "コースの巡礼スポットに実際に訪れる",
            imageNames: ["guide_2"],
            description: "実際に聖地巡礼スポットに訪れてみましょう。\n現在地のピンが聖地巡礼達成エリア（藍色の円）の中に入っていればOK！",
            supplement: "現在地は地図の右下にあるボタンをタップすると更新されます。"
        ),
        HowToUseStep(
            title: "「ココキタ」ボタンをタップ",
            imageNames: [],
            description: "左下の「ココキタ」ボタンをタップして、現在地を記録しましょう。",
            supplement: "記録モードで記録しても聖地巡礼判定は行われます。\n巡礼モードで記録した記録は記録モードでも確認できます。"
        ),
        HowToUseStep(
            title: "聖地巡礼達成！",
            imageNames: ["guide_3", "guide_4"],
            description: "聖地巡礼が達成されたスポットはチェックマークがつきます。"
        ),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        StepCard(number: index + 1, step: step)
                    }
                }
                .padding(20)
            }
            .navigationTitle(L.PilgrimageHome.howToUseTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.Common.close) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - ステップデータ

private struct HowToUseStep {
    let title: String
    /// スクリーンショット画像名（空の場合は画像なし）
    let imageNames: [String]
    let description: String
    /// 補足テキスト（小さめフォントで表示、省略可）
    var supplement: String? = nil
}

// MARK: - ステップカード

private struct StepCard: View {
    let number: Int
    let step: HowToUseStep

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // ステップ番号 ＋ タイトル
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.indigo)
                        .frame(width: 28, height: 28)
                    Text("\(number)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
                Text(step.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // スクリーンショット（1枚: 半幅中央寄せ / 2枚: 横並び等幅）
            if !step.imageNames.isEmpty {
                if step.imageNames.count == 1 {
                    HStack {
                        Spacer()
                        screenshot(step.imageNames[0])
                            .containerRelativeFrame(.horizontal, count: 2, span: 1, spacing: 10)
                        Spacer()
                    }
                } else {
                    HStack(spacing: 10) {
                        ForEach(step.imageNames, id: \.self) { name in
                            screenshot(name)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }

            // 説明
            Text(step.description)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            // 補足（省略可・小さめフォント）
            if let supplement = step.supplement {
                Text(supplement)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func screenshot(_ name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(uiColor: .systemGray4), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
    }
}
