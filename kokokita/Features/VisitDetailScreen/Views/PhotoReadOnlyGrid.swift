import SwiftUI

struct PhotoReadOnlyGrid: View {
    let paths: [String]
    var thumbSize: CGFloat = 64
    @Binding var fullScreenIndex: Int?

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: thumbSize), spacing: 5)], spacing: 5) {
            ForEach(paths.indices, id: \.self) { idx in
                let path = paths[idx]
                PhotoThumb(
                    path: path,
                    size: thumbSize,
                    showDelete: false,
                    onTap: { fullScreenIndex = idx }
                )
            }
        }
        .padding(.vertical, 10)
    }
}
