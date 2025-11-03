import SwiftUI

/// 画面下部に固定表示する大ボタン（PayPay風）
struct BigFooterButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Spacer()
                Label(title, systemImage: systemImage)
                    .font(.title2).bold()
                Spacer()
            }
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(radius: 4)
        }
        .padding(.horizontal)
    }
}
