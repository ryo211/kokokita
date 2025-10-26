//
//  PromptViews.swift
//  kokokita
//
//  Created by 橋本遼 on 2025/09/23.
//

import SwiftUI

struct PostKokokitaPromptSheet: View {
    let locationData: LocationData
    let onQuickSave: () -> Void
    let onOpenEditor: () -> Void
    let onOpenPOI: () -> Void
    let onCancel: () -> Void

    private var timestamp: Date? { locationData.timestamp }
    private var addressText: String? { locationData.address }
    private var latitude: Double { locationData.latitude }
    private var longitude: Double { locationData.longitude }
    private var canSave: Bool { latitude != 0 || longitude != 0 }
    
    // 1%の確率でレア画像を表示
    private var logoImageName: String {
        Double.random(in: 0..<1) < 0.01 ? "kokokita_irodori" : "kokokita_irodori_blue"
    }

    var body: some View {
        VStack(spacing: 16) {
            // 見出し
            HStack(spacing: 10) {
                Image(logoImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 42)
                Text("ココキタ  ✅")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .tracking(1.2)  // 文字間隔を広げる
                    .foregroundColor(.accentColor)
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
                    action: onQuickSave
                )

                actionButton(
                    primary: false,
                    systemImage: "square.and.pencil",
                    title: "情報を入力",
                    subtitle: "タイトル・メモなど",
                    action: onOpenEditor
                )

                actionButton(
                    primary: false,
                    systemImage: "building.2.crop.circle",
                    title: "ココカモ",
                    subtitle: "周囲の場所を表示・選択",
                    action: onOpenPOI
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
