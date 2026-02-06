import SwiftUI

/// グループ帰属バッジ
///
/// チップとは異なるデザインで「この記録がどのグループ（フォルダ）に属しているか」を表す。
/// フォルダアイコン＋グループ名をインラインで表示する。
struct GroupBadge: View {
    let name: String
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 3 : 4) {
            Image(systemName: "folder.fill")
                .font(compact ? .caption2.bold() : .caption.bold())
            Text(name)
                .font(compact ? .caption2.bold() : .caption.bold())
                .lineLimit(1)
        }
        .foregroundStyle(.secondary)
    }
}
