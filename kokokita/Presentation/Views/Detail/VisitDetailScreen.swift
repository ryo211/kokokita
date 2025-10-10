//
//  VisitDetailScreen.swift
//  kokokita
//
//  Created by 橋本遼 on 2025/10/03.
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - 詳細画面
struct VisitDetailScreen: View {
    let data: VisitDetailData
    let onBack: () -> Void
    let onEdit: () -> Void
    let onShare: () -> Void

    // 地図カメラ
    @State private var camera: MapCameraPosition
    
//    @State private var shareImage: UIImage? = nil
//    @State private var showShareSheet = false
    @State private var sharePayload: SharePayload? = nil
    // SNSカードの論理サイズ（表示用は1/3で描画、保存はscale=3で 1080x1350）
    private let logicalSize = CGSize(width: 360, height: 450)
    
    init(data: VisitDetailData,
         onBack: @escaping () -> Void = {},
         onEdit: @escaping () -> Void = {},
         onShare: @escaping () -> Void = {}) {
        self.data = data
        self.onBack = onBack
        self.onEdit = onEdit
        self.onShare = onShare

        if let c = data.coordinate {
            let region = MKCoordinateRegion(center: c,
                                            latitudinalMeters: 600,
                                            longitudinalMeters: 600)
            _camera = State(initialValue: .region(region))
        } else {
            _camera = State(initialValue: .automatic) // 位置なし
        }
    }

    var body: some View {
        ZStack {
            // 背景：淡いグラデーション
            LinearGradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VisitDetailContent(data: data, mapSnapshot: nil, isSharing: false)
            }

        }
        // ▼ 標準の戻るボタンを活かしつつ、右側に「編集」を出す
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    onEdit()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.pencil")
                        Text("編集")
                    }
                    .font(.subheadline.weight(.semibold))
                }

                Button {
                    Task { await makeAndShare() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text("共有")
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
        }

        .sheet(item: $sharePayload) { payload in
            ActivityView(items: [payload.text, payload.image])
        }
    }
    
    private func shareText() -> String {
        var lines: [String] = []
        lines.append(data.title.ifBlank("（タイトルなし）"))
        lines.append(data.timestamp.kokokitaVisitString)
        if let addr = data.address?.trimmingCharacters(in: .whitespacesAndNewlines), !addr.isEmpty {
            lines.append(addr)
        }
        return lines.joined(separator: "\n")
    }

    private func shareMapSize() -> CGSize {
        // 共有カード内の地図高さと同じにする（余白込みで多少小さめでもOK）
        CGSize(width: logicalSize.width, height: 300)
    }

    private func makeAndShare() async {
        // 1) 地図スナップショット（オフスクリーンでも確実に出る）
        var mapImage: UIImage? = nil
        if let c = data.coordinate {
            mapImage = await MapSnapshotService.makeSnapshot(
                center: c,
                size: CGSize(width: 360, height: 300),
                spanMeters: 300,
                showCoordinateBadge: true,   // ← バッジを載せる
                decimals: 4,
                badgeInset: 8
            )
        }

        // 2) 同じ中身を共有用フラグでレンダリング
        let img: UIImage? = await MainActor.run {
            let content = VStack(spacing: 0) {
                VisitDetailContent(data: data, mapSnapshot: mapImage, isSharing: true)
                    .padding(.all, 20)
            }
            return ShareImageRenderer.renderWidth(content, width: 360, scale: 3) // 1080px 幅
        }

        // 3) シート表示（前回の SharePayload 方式）
        if let img {
            await MainActor.run {
                self.sharePayload = SharePayload(image: img, text: shareText())
            }
        }
    }


    
}

// MARK: - データ受け渡し用の軽量モデル（UI草案用）
struct VisitDetailData {
    var title: String
    var labels: [String]
    var group: String?
    var timestamp: Date
    var address: String?
    var coordinate: CLLocationCoordinate2D?
    var memo: String?
    var facility: FacilityInfo?
    var photoPaths: [String]
}


struct SharePayload: Identifiable {
    let id = UUID()
    let image: UIImage
    let text: String
}
