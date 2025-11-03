import SwiftUI
import Photos


import SwiftUI
import Photos

struct PhotoPager: View {
    struct IndexWrapper: Identifiable { let index: Int; var id: Int { index } }

    let paths: [String]
    @State var current: Int
    @Environment(\.dismiss) private var dismiss

    @State private var showToast = false

    init(paths: [String], startIndex: Int) {
        self.paths = paths
        _current = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $current) {
                ForEach(paths.indices, id: \.self) { i in
                    SimpleImageView(path: paths[i]).tag(i)
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
                    Button { dismiss() } label: {
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
            .padding(.top, 8)
            .padding(.trailing, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .statusBarHidden(true)

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


private struct SimpleImageView: View {
    let path: String

    var body: some View {
        GeometryReader { geo in
            if let img = ImageStore.load(path) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()                         // ← 画面にフィット
                    .frame(width: geo.size.width,
                           height: geo.size.height)
                    .background(Color.black)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())             // ← タッチ領域を画像全体に
            } else {
                Color.black.ignoresSafeArea()
            }
        }
    }
}

