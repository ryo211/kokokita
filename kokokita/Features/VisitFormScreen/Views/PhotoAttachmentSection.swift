import SwiftUI
import PhotosUI
import UIKit

@available(iOS 16.0, *)
struct PhotoAttachmentSection: View {
    @Bindable var vm: VisitFormStore
    var allowDelete: Bool = true
    var thumbSize: CGFloat = 64

    @State private var libSelection: [PhotosPickerItem] = []
    @State private var showCamera = false
    @State private var fullScreenIndex: Int? = nil
    @State private var photoDragOffset: CGFloat = 0

    private var canAddMore: Bool { vm.photoEffects.photoPathsEditing.count < AppConfig.maxPhotosPerVisit }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            LazyVGrid(columns: [GridItem(.adaptive(minimum: thumbSize), spacing: 5)], spacing: 5)  {
                ForEach(Array(vm.photoEffects.photoPathsEditing.enumerated()), id: \.offset) { idx, path in
                    PhotoThumb(
                        path: path,
                        size: thumbSize,
                        showDelete: allowDelete,
                        onTap: { fullScreenIndex = idx },
                        onDelete: allowDelete ? {
                            vm.removePhoto(at: idx)
                            // フルスクリーン表示中の場合は閉じる
                            if fullScreenIndex == idx {
                                fullScreenIndex = nil
                            } else if let currentIndex = fullScreenIndex, currentIndex > idx {
                                // 削除した写真より後ろを表示中の場合、インデックスを調整
                                fullScreenIndex = currentIndex - 1
                            }
                        } : nil
                    )
                }
            }
            .padding(.top, 2)

            // "写真 / カメラ" ボタン（サムネ列の下）
            if allowDelete && canAddMore {
                HStack(spacing: 12) {
                    PhotosPicker(
                        selection: $libSelection,
                        maxSelectionCount: AppConfig.maxPhotosPerVisit - vm.photoEffects.photoPathsEditing.count,
                        matching: .images
                    ) {
                        Label(L.Photo.photo, systemImage: "photo.on.rectangle")
                    }
                    .onChange(of: libSelection) {
                        Task { await loadSelectedLibraryItems() }
                    }

                    Button {
                        showCamera = true
                    } label: {
                        Label(L.Photo.camera, systemImage: "camera")
                    }
                    .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)

        // カメラ
        .sheet(isPresented: $showCamera) {
            CameraPicker { ui in
                vm.addPhotos([ui])
            }
            .ignoresSafeArea()
        }

        // フルスクリーンプレビュー
        .fullScreenCover(item: Binding(
            get: { fullScreenIndex.map { PhotoPager.IndexWrapper(index: $0) } },
            set: { fullScreenIndex = $0?.index }
        )) { wrapper in
            PhotoPager(
                paths: vm.photoEffects.photoPathsEditing,
                startIndex: wrapper.index,
                externalDragOffset: $photoDragOffset
            )
        }
    }

    // MARK: - Helpers
    @MainActor
    private func loadSelectedLibraryItems() async {
        guard !libSelection.isEmpty else { return }
        var imgs: [UIImage] = []
        imgs.reserveCapacity(libSelection.count)

        for item in libSelection {
            if let data = try? await item.loadTransferable(type: Data.self),
               let ui = UIImage(data: data) {
                imgs.append(ui)
            }
        }
        vm.addPhotos(imgs)
        libSelection = []
    }
}
