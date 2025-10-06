//
//  FilterChip.swift
//  kokokita
//
//  Created by 橋本遼 on 2025/09/30.
//

import SwiftUI

//struct FilterChip: View {
//    let text: String
//    let systemImage: String?
//    let tint: Color
//    let onRemove: () -> Void
//
//    init(_ text: String, systemImage: String? = nil, tint: Color = .secondary, onRemove: @escaping () -> Void) {
//        self.text = text; self.systemImage = systemImage; self.tint = tint; self.onRemove = onRemove
//    }
//
//    var body: some View {
//        HStack(spacing: 6) {
//            if let img = systemImage { Image(systemName: img) }
//            Text(text).lineLimit(1)
//            Button(action: onRemove) {
//                Image(systemName: "xmark.circle.fill")
//            }
//            .buttonStyle(.plain)
//        }
//        .font(.caption)
//        .padding(.vertical, 6).padding(.horizontal, 10)
//        .background(tint.opacity(0.15), in: Capsule())
//        .foregroundStyle(tint)
//    }
//}
