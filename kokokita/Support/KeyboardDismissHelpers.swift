//
//  KeyboardDismissHelpers.swift
//  kokokita
//
//  Created by 橋本遼 on 2025/09/24.
//

import SwiftUI

struct DismissKeyboardBackground: UIViewRepresentable {
    let onTap: () -> Void

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        let g = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.tapped)
        )
        g.cancelsTouchesInView = false // ← これでボタンのタップを妨げない
        v.addGestureRecognizer(g)
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    final class Coordinator: NSObject {
        let onTap: () -> Void
        init(onTap: @escaping () -> Void) { self.onTap = onTap }
        @objc func tapped() { onTap() }
    }
}

extension View {
    func dismissKeyboardOnBackgroundTap(_ action: @escaping () -> Void) -> some View {
        background(DismissKeyboardBackground(onTap: action))
    }
}
