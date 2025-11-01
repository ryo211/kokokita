import SwiftUI

struct PhotoReadOnlyGrid: View {
    let paths: [String]
    var thumbSize: CGFloat = 64

    @State private var fullScreenIndex: Int? = nil

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
        .fullScreenCover(item: Binding(
            get: { fullScreenIndex.map { PhotoPager.IndexWrapper(index: $0) } },
            set: { fullScreenIndex = $0?.index }
        )) { wrapper in
            PhotoPager(paths: paths, startIndex: wrapper.index)
        }
    }
}
