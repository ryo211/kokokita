//
//  PhotoThumb.swift
//  kokokita
//
//  Created by 橋本遼 on 2025/10/07.
//

// Shared/Media/PhotoThumb.swift
import SwiftUI

struct PhotoThumb: View {
    let path: String
    var size: CGFloat
    var showDelete: Bool = true
    var onTap: () -> Void
    var onDelete: (() -> Void)? = nil

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let img = ImageStore.load(path) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6))
                        Image(systemName: "photo").foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: size, height: size)
            .clipped()
            .cornerRadius(10)
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .onTapGesture { onTap() }

            if showDelete, let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .font(.title3)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 1.5, x: 0, y: 1) // 薄い影
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.85), lineWidth: 1) // 白縁でコントラスト強化
                        )
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.3)) // 下地を少し暗く
                        )
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
            }
        }
    }
}
