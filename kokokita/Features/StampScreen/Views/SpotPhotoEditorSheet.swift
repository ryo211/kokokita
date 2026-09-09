import SwiftUI
import PhotosUI

// スタンプ詳細画面のスポットカスタム写真編集シート
// メイン1枚+サブ3枚(計4枚)を、フォトライブラリまたは訪問記録の写真から設定できる
struct SpotPhotoEditorSheet: View {
    let spot: CourseSpot
    let visitPhotoPaths: [String]
    let onSave: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var photoPaths: [String?]
    @State private var activeSlotIndex: Int? = nil
    @State private var showSourceDialog = false
    @State private var showVisitPhotoPicker = false
    @State private var libraryItem: PhotosPickerItem? = nil
    // PhotosPicker表示制御用（confirmationDialogとは別トリガーにして表示タイミングの競合を避ける）
    @State private var showLibraryPickerRequested = false

    init(spot: CourseSpot, initialPhotoPaths: [String], visitPhotoPaths: [String], onSave: @escaping ([String]) -> Void) {
        self.spot = spot
        self.visitPhotoPaths = visitPhotoPaths
        self.onSave = onSave
        var slots: [String?] = Array(repeating: nil, count: 4)
        for (index, path) in initialPhotoPaths.prefix(4).enumerated() {
            slots[index] = path
        }
        _photoPaths = State(initialValue: slots)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(L.Stamp.photoEditorDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                // メインを大きく中心に、サブ3枚をその下に小さく並べる
                VStack(spacing: 12) {
                    slotView(index: 0)
                        .frame(width: 180, height: 180)

                    HStack(spacing: 10) {
                        ForEach(1..<4, id: \.self) { index in
                            slotView(index: index)
                                .frame(width: 96, height: 96)
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                Spacer()
            }
            .navigationTitle(L.Stamp.editPhotosButton)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L.Common.close) { dismiss() }
                }
            }
            .onChange(of: photoPaths) { _, _ in save() }
            .confirmationDialog(L.Stamp.photoSourceTitle, isPresented: $showSourceDialog, titleVisibility: .visible) {
                Button(L.Stamp.photoSourceLibrary) {
                    // confirmationDialog を閉じてから PhotosPicker を出す必要があるため次の runloop に回す
                    DispatchQueue.main.async {
                        showLibraryPickerRequested = true
                    }
                }
                Button(L.Stamp.photoSourceVisit) { showVisitPhotoPicker = true }
                if let index = activeSlotIndex, photoPaths[index] != nil {
                    if index == 0 {
                        Button(L.Stamp.photoResetToDefault, role: .destructive) { photoPaths[index] = nil }
                    } else {
                        Button(L.Common.delete, role: .destructive) { photoPaths[index] = nil }
                    }
                }
                Button(L.Common.cancel, role: .cancel) {}
            }
            .photosPicker(isPresented: $showLibraryPickerRequested, selection: $libraryItem, matching: .images)
            .onChange(of: libraryItem) { _, newItem in
                guard let newItem else { return }
                Task { await loadLibraryImage(newItem) }
            }
            .sheet(isPresented: $showVisitPhotoPicker) {
                VisitPhotoPickerSheet(photoPaths: visitPhotoPaths) { selectedPath in
                    applyVisitPhoto(selectedPath)
                }
            }
        }
    }

    @ViewBuilder
    private func slotView(index: Int) -> some View {
        Button {
            activeSlotIndex = index
            showSourceDialog = true
        } label: {
            ZStack {
                if let path = photoPaths[index], let uiImage = LocalImageStorage.shared.load(from: path) {
                    Color.clear.overlay {
                        Image(uiImage: uiImage).resizable().scaledToFill()
                    }
                    .clipped()
                } else if index == 0 {
                    // メインスロットが未設定の場合は、元々のスポット画像をプレビューとして見せる
                    // （ここではまだ保存はされず、他の写真に切り替えるかどうかを選べる状態）
                    courseCoverImage(
                        localPath: spot.localCoverImagePath,
                        remoteURLString: spot.coverImageUrl,
                        placeholder: { emptySlotPlaceholder }
                    )
                } else {
                    emptySlotPlaceholder
                }

                if index == 0 {
                    Text(L.Stamp.photoSlotMain)
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.indigo, in: Capsule())
                        .padding(6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
        }
        .buttonStyle(.plain)
        .aspectRatio(1, contentMode: .fill)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.indigo.opacity(0.4), lineWidth: 1.5)
        )
    }

    private var emptySlotPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.tertiarySystemFill))
            VStack(spacing: 6) {
                Image(systemName: "camera.fill")
                    .font(.title2)
                Text(L.Stamp.photoSlotEmpty)
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
    }

    private func loadLibraryImage(_ item: PhotosPickerItem) async {
        defer { libraryItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }
        do {
            let path = try LocalImageStorage.shared.save(uiImage, id: UUID().uuidString)
            if let index = activeSlotIndex {
                photoPaths[index] = path
            }
        } catch {
            Logger.error("スポット写真の保存に失敗しました: \(error)")
        }
    }

    private func applyVisitPhoto(_ relativePath: String) {
        guard let uiImage = ImageStore.load(relativePath) else { return }
        do {
            let path = try LocalImageStorage.shared.save(uiImage, id: UUID().uuidString)
            if let index = activeSlotIndex {
                photoPaths[index] = path
            }
        } catch {
            Logger.error("訪問記録写真のコピーに失敗しました: \(error)")
        }
    }

    private func save() {
        let paths = photoPaths.compactMap { $0 }
        do {
            try AppContainer.shared.courseRepo.updateSpotPhotos(spotId: spot.id, paths: paths)
            NotificationCenter.default.post(name: .courseChanged, object: nil)
            onSave(paths)
        } catch {
            Logger.error("スポット写真の保存に失敗しました: \(error)")
        }
    }
}

// MARK: - 訪問記録の写真から選ぶシート

private struct VisitPhotoPickerSheet: View {
    let photoPaths: [String]
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if photoPaths.isEmpty {
                    ContentUnavailableView(
                        L.Stamp.visitPhotoPickerTitle,
                        systemImage: "photo.on.rectangle",
                        description: Text(L.Stamp.visitPhotoPickerEmpty)
                    )
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                            spacing: 8
                        ) {
                            ForEach(photoPaths, id: \.self) { path in
                                Button {
                                    onSelect(path)
                                    dismiss()
                                } label: {
                                    photoThumbnail(path: path)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle(L.Stamp.visitPhotoPickerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L.Common.cancel) { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func photoThumbnail(path: String) -> some View {
        Group {
            if let uiImage = ImageStore.load(path) {
                Color.clear.overlay {
                    Image(uiImage: uiImage).resizable().scaledToFill()
                }
                .clipped()
            } else {
                Color(.tertiarySystemFill)
            }
        }
        .aspectRatio(1, contentMode: .fill)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
