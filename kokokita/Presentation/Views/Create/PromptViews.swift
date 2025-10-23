//
//  PromptViews.swift
//  kokokita
//
//  Created by 橋本遼 on 2025/09/23.
//

import SwiftUI

struct PostKokokitaPromptSheet: View {
    let timestamp: Date?
    let addressText: String?
    let latitude: Double
    let longitude: Double
    let canSave: Bool

    let onSaveNow: () -> Void
    let onManualInput: () -> Void
    let onPickPOI: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // 見出し
            HStack(spacing: 10) {
//                Image(systemName: "mappin.and.ellipse")
//                    .font(.title2.weight(.semibold))
//                    .foregroundStyle(.tint)
                Image("kokokita_irodori_blue")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 42)
                Text("ココキタ！")
                    .font(.title2.bold())
            }
            .padding(.top, 8)

            // 最低限の情報（小さく）
            VStack(spacing: 4) {
                Text(formattedTimestamp)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let addr = addressText, !addr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(addr)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 16)
                }
            }
         
            if latitude != 0 || longitude != 0 {
                MapPreview(
                    lat: latitude,
                    lon: longitude,
                    showCoordinateOverlay: true,
                    decimals: 5
                )
                    .frame(height: 180)
            } else {
                Text("位置情報がありません")
                    .foregroundStyle(.secondary)
            }
            // 3つの選択肢（同列）
            HStack(spacing: 12) {
                actionButton(
                    primary: true,
                    systemImage: "checkmark.circle.fill",
                    title: "そのまま保存",
                    subtitle: "後で編集できます",
                    isDisabled: !canSave,
                    action: onSaveNow
                )

                actionButton(
                    primary: false,
                    systemImage: "square.and.pencil",
                    title: "情報を入力",
                    subtitle: "タイトル・メモなど",
                    action: onManualInput
                )

                actionButton(
                    primary: false,
                    systemImage: "building.2.crop.circle",
                    title: "周囲から",
                    subtitle: "場所の候補を表示・選択",
                    action: onPickPOI
                )
            }
            .frame(height: 120)
            .padding(.horizontal, 8)


            Spacer(minLength: 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
        )
        .presentationDragIndicator(.visible)
    }
    
    private var formattedTimestamp: String {
        guard let ts = timestamp else { return "-" }
        return ts.kokokitaVisitString
    }
    
    @ViewBuilder
    private func actionButton(
        primary: Bool,
        systemImage: String,
        title: String,
        subtitle: String,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 6) {
            // 中身（アイコン＋タイトル）は一度だけ組む
            let content = VStack(spacing: 6) {
                Image(systemName: systemImage).font(.title2)
                Text(title).font(.subheadline.bold())
            }
            .frame(maxWidth: .infinity, minHeight: 56)

            // ★ Button は“必ず1つだけ”作る
            if #available(iOS 15.0, *) {
                if primary {
                    Button(action: action) { content }
                        .buttonStyle(BorderedProminentButtonStyle())
                        .controlSize(.large)
                        .buttonBorderShape(.roundedRectangle(radius: 14))
                        .disabled(isDisabled)
                        .lineLimit(2)
                } else {
                    Button(action: action) { content }
                        .buttonStyle(BorderedButtonStyle())
                        .controlSize(.large)
                        .buttonBorderShape(.roundedRectangle(radius: 14))
                        .disabled(isDisabled)
                        .lineLimit(2)
                }
            } else {
                // フォールバック（旧OS向け）
                Button(action: action) { content }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(primary ? Color.accentColor : Color.clear)
                    .foregroundColor(primary ? .white : .accentColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.accentColor, lineWidth: primary ? 0 : 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .disabled(isDisabled)
                    .lineLimit(2) 
            }

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }


}
