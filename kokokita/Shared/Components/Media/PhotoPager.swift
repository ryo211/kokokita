import SwiftUI
import Photos


import SwiftUI
import Photos

struct PhotoPager: View {
    struct IndexWrapper: Identifiable { let index: Int; var id: Int { index } }

    let paths: [String]
    @State var current: Int
    var onDismiss: (() -> Void)? = nil
    @Binding var externalDragOffset: CGFloat  // 外部に公開するドラッグ量
    @Environment(\.dismiss) private var dismiss

    @State private var showToast = false
    @State private var dragOffset: CGFloat = 0
    @State private var dragScale: CGFloat = 1.0

    init(paths: [String], startIndex: Int, externalDragOffset: Binding<CGFloat>, onDismiss: (() -> Void)? = nil) {
        self.paths = paths
        _current = State(initialValue: startIndex)
        _externalDragOffset = externalDragOffset
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            Color.black
                .opacity(backgroundOpacity)
                .ignoresSafeArea()

            TabView(selection: $current) {
                ForEach(paths.indices, id: \.self) { i in
                    DraggableImageView(
                        path: paths[i],
                        dragOffset: $dragOffset,
                        dragScale: $dragScale,
                        externalDragOffset: $externalDragOffset,
                        onDismiss: {
                            if let callback = onDismiss {
                                callback()
                            } else {
                                dismiss()
                            }
                        }
                    )
                    .tag(i)
                }
            }
            .tabViewStyle(.page)

            // ▼ ここを変更：右上のボタン群 + その直下にトースト
            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 16) {
                    Button { saveCurrentPhoto() } label: {
                        Image(systemName: "square.and.arrow.down")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding(12)
                    }
                    Button {
                        if let callback = onDismiss {
                            callback()
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding(12)
                    }
                }

                if showToast {
                    Text("保存しました")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.8))
                        .clipShape(Capsule())
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.25), value: showToast)
                }
            }
            .padding(.top, 110)
            .padding(.trailing, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .statusBarHidden(true)
    }

    // ドラッグ量に応じて背景の透明度を変化
    private var backgroundOpacity: Double {
        let maxOffset: CGFloat = 300
        let progress = min(abs(dragOffset) / maxOffset, 1.0)
        return 1.0 - (progress * 0.7) // ドラッグに応じて透明に
    }

    private func saveCurrentPhoto() {
        guard paths.indices.contains(current),
              let img = ImageStore.load(paths[current]) else { return }
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: img)
            }) { success, error in
                if success {
                    DispatchQueue.main.async {
                        showToast = true
                        // 2秒後に自動でフェードアウト
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { showToast = false }
                        }
                    }
                }
            }
        }
    }
}


private struct DraggableImageView: View {
    let path: String
    @Binding var dragOffset: CGFloat
    @Binding var dragScale: CGFloat
    @Binding var externalDragOffset: CGFloat
    let onDismiss: () -> Void

    @State private var localOffset: CGFloat = 0
    @State private var isVerticalDrag = false
    @State private var currentMagnification: CGFloat = 1.0
    @State private var finalMagnification: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            if let img = ImageStore.load(path) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(currentScale * currentMagnification * finalMagnification)
                    .offset(y: localOffset)
                    .gesture(
                        DragGesture(minimumDistance: 20)
                            .onChanged { value in
                                // 最初の動きで縦か横かを判定
                                if !isVerticalDrag {
                                    isVerticalDrag = abs(value.translation.height) > abs(value.translation.width)
                                }

                                // 縦方向のドラッグのみ処理（横方向はTabViewに任せる）
                                if isVerticalDrag {
                                    localOffset = value.translation.height
                                    dragOffset = value.translation.height
                                    externalDragOffset = value.translation.height  // 外部に公開

                                    // スケールをドラッグ量に応じて変化
                                    let progress = min(abs(value.translation.height) / 300, 1.0)
                                    dragScale = 1.0 - (progress * 0.2) // 最大20%縮小
                                }
                            }
                            .onEnded { value in
                                guard isVerticalDrag else {
                                    isVerticalDrag = false
                                    return
                                }

                                // 閉じる判定
                                let threshold: CGFloat = 150
                                let velocity = (value.predictedEndLocation.y - value.location.y)

                                if abs(localOffset) > threshold || abs(velocity) > 1000 {
                                    // 閉じる
                                    onDismiss()
                                } else {
                                    // 元に戻す
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        localOffset = 0
                                        dragOffset = 0
                                        dragScale = 1.0
                                        externalDragOffset = 0  // 外部にもリセットを通知
                                    }
                                }

                                isVerticalDrag = false
                            }
                    )
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                currentMagnification = value
                            }
                            .onEnded { value in
                                finalMagnification *= currentMagnification
                                // 最小1.0、最大5.0に制限
                                finalMagnification = min(max(finalMagnification, 1.0), 5.0)
                                currentMagnification = 1.0
                            }
                    )
                    .onTapGesture(count: 2) {
                        // ダブルタップでズームリセット
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            finalMagnification = 1.0
                            currentMagnification = 1.0
                        }
                    }
                    .contentShape(Rectangle())
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .background(Color.clear)
    }

    private var currentScale: CGFloat {
        dragScale
    }
}

private struct SimpleImageView: View {
    let path: String

    var body: some View {
        GeometryReader { geo in
            if let img = ImageStore.load(path) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .background(Color.black)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
            } else {
                Color.black.ignoresSafeArea()
            }
        }
    }
}

