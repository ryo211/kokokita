import SwiftUI
import PhotosUI
import MapKit

/// 後付け記録画面
struct ManualEntryScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = ManualEntryStore()

    // PhotosPicker用
    @State private var showCamera = false

    // 場所設定シート
    @State private var showLocationPicker = false

    // フルスクリーン写真表示
    @State private var fullScreenIndex: Int? = nil
    @State private var photoDragOffset: CGFloat = 0

    // ラベル/グループ/メンバー候補
    @State private var labelOptions: [LabelTag] = []
    @State private var groupOptions: [GroupTag] = []
    @State private var memberOptions: [MemberTag] = []

    // ピッカー/作成シート
    @State private var labelPickerShown = false
    @State private var groupPickerShown = false
    @State private var memberPickerShown = false
    @State private var labelCreateShown = false
    @State private var groupCreateShown = false
    @State private var memberCreateShown = false

    // 作成入力
    @State private var newLabelName = ""
    @State private var newLabelColorId: String? = nil
    @State private var newGroupName = ""
    @State private var newMemberName = ""

    var body: some View {
        NavigationStack {
            formContent
                .navigationTitle(L.ManualEntry.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .alert(item: alertBinding) { alertView(for: $0) }
                .sheet(isPresented: $showLocationPicker) { locationPickerSheet }
                .sheet(isPresented: $showCamera) { cameraSheet }
                .fullScreenCover(item: fullScreenBinding) { photoFullScreen(for: $0) }
                .task { await loadTaxonomyOptions() }
        }
        .sheet(isPresented: $labelPickerShown) { labelPickerSheetContent }
        .sheet(isPresented: $groupPickerShown) { groupPickerSheetContent }
        .sheet(isPresented: $memberPickerShown) { memberPickerSheetContent }
    }

    // MARK: - Load Taxonomy Options

    private func loadTaxonomyOptions() async {
        labelOptions = ((try? AppContainer.shared.repo.allLabels()) ?? []).sortedByName
        groupOptions = ((try? AppContainer.shared.repo.allGroups()) ?? []).sortedByName
        memberOptions = ((try? AppContainer.shared.repo.allMembers()) ?? []).sortedByName
    }

    // MARK: - Form Content

    private var formContent: some View {
        Form {
            locationSection
            dateTimeSection
            metadataSection
            taxonomySection
            photoSection
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(L.Common.cancel) { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(L.Common.save) {
                if store.save() { dismiss() }
            }
            .disabled(!store.canSave)
            .fontWeight(.bold)
        }
    }

    // MARK: - Alert

    private var alertBinding: Binding<AlertMsg?> {
        Binding(
            get: { store.alert.map { AlertMsg(id: UUID(), text: $0) } },
            set: { _ in store.alert = nil }
        )
    }

    private func alertView(for msg: AlertMsg) -> Alert {
        Alert(
            title: Text(L.Common.error),
            message: Text(msg.text),
            dismissButton: .default(Text(L.Common.ok))
        )
    }

    // MARK: - Sheets

    private var locationPickerSheet: some View {
        LocationPickerSheet(
            latitude: $store.latitude,
            longitude: $store.longitude,
            addressLine: $store.addressLine,
            placeName: $store.title
        ) { coordinate, timestamp, image in
            // 写真から取り込み時のコールバック
            handlePhotoImport(coordinate: coordinate, timestamp: timestamp, image: image)
        }
    }

    private func handlePhotoImport(coordinate: CLLocationCoordinate2D?, timestamp: Date?, image: UIImage?) {
        let hasLocation = coordinate != nil
        let hasTimestamp = timestamp != nil && timestamp! <= Date()

        // 日時を設定
        if let timestamp = timestamp, timestamp <= Date() {
            store.timestampDisplay = timestamp
        }

        // 写真を追加
        if let image = image {
            store.addPhotos([image])
        }

        store.isPhotoImported = true

        // 位置情報または日時情報がない場合はエラーメッセージを表示
        if !hasLocation && !hasTimestamp {
            store.alert = L.ManualEntry.noLocationInPhoto + "\n" + L.ManualEntry.noDateInPhoto
        } else if !hasLocation {
            store.alert = L.ManualEntry.noLocationInPhoto
        } else if !hasTimestamp {
            store.alert = L.ManualEntry.noDateInPhoto
        }
    }

    private var cameraSheet: some View {
        CameraPicker { image in
            store.addPhotos([image])
        }
        .ignoresSafeArea()
    }

    // MARK: - Full Screen Photo

    private var fullScreenBinding: Binding<PhotoPager.IndexWrapper?> {
        Binding(
            get: { fullScreenIndex.map { PhotoPager.IndexWrapper(index: $0) } },
            set: { fullScreenIndex = $0?.index }
        )
    }

    private func photoFullScreen(for wrapper: PhotoPager.IndexWrapper) -> some View {
        PhotoPager(
            paths: store.photoEffects.photoPathsEditing,
            startIndex: wrapper.index,
            externalDragOffset: $photoDragOffset
        )
    }

    // MARK: - Sections

    private var locationSection: some View {
        Section {
            // 場所名と設定ボタン
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(store.hasValidLocation ? .orange : .secondary)

                if store.hasValidLocation {
                    // 場所が設定されている場合は場所名を表示
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.title.isEmpty ? store.addressLine ?? "" : store.title)
                            .font(.subheadline)
                        if !store.title.isEmpty, let address = store.addressLine {
                            Text(address)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                } else {
                    // 場所が未設定の場合
                    Text(L.ManualEntry.locationRequired)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    showLocationPicker = true
                } label: {
                    Text(L.ManualEntry.setLocation)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // 緯度経度表示（設定済みの場合のみ）
            if let lat = store.latitude, let lon = store.longitude {
                HStack {
                    Image(systemName: "location")
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.5f, %.5f", lat, lon))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        } header: {
            Text(L.ManualEntry.setLocation)
        } footer: {
            if !store.hasValidLocation {
                Text(L.ManualEntry.locationRequired)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var dateTimeSection: some View {
        Section {
            DatePicker(
                L.ManualEntry.dateTime,
                selection: $store.timestampDisplay,
                in: ...Date(),
                displayedComponents: [.date, .hourAndMinute]
            )
        } header: {
            Text(L.ManualEntry.setDateTime)
        } footer: {
            if !store.hasValidTimestamp {
                Text(L.ManualEntry.futureDateNotAllowed)
                    .foregroundStyle(.red)
            }
        }
    }

    private var metadataSection: some View {
        Section {
            TextField(L.VisitEdit.titlePlaceholder, text: $store.title)
            TextField(L.VisitEdit.memoPlaceholder, text: $store.comment, axis: .vertical)
                .lineLimit(3...6)
        } header: {
            Text(L.VisitEdit.basicInfoSection)
        }
    }

    // MARK: - Taxonomy Section

    private var taxonomySection: some View {
        Section {
            // グループ
            groupRow

            // ラベル
            labelRow

            // メンバー
            memberRow
        } header: {
            Text(L.VisitEdit.taxonomySection)
        }
    }

    @ViewBuilder
    private var groupRow: some View {
        if store.groupId == nil {
            // 未選択時：選択ボタン + 追加ボタンを表示
            HStack(spacing: UIConstants.Spacing.medium) {
                Button { groupPickerShown = true } label: {
                    Label(L.VisitEdit.selectGroup, systemImage: "folder")
                        .foregroundStyle(ChipKind.defaultTint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    groupPickerShown = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(ChipKind.defaultTint)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
            }
        } else if let groupId = store.groupId, let name = groupOptions.first(where: { $0.id == groupId })?.name {
            // 選択済み時：フォルダ帰属表示 + 変更/削除ボタン
            HStack(alignment: .center, spacing: UIConstants.Spacing.medium) {
                Button { groupPickerShown = true } label: {
                    GroupBadge(name: name)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    store.groupId = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .imageScale(.medium)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var labelRow: some View {
        if store.labelIds.isEmpty {
            // 未選択時：選択ボタン + 追加ボタンを表示
            HStack(spacing: UIConstants.Spacing.medium) {
                Button { labelPickerShown = true } label: {
                    Label(L.VisitEdit.selectLabel, systemImage: "tag")
                        .foregroundStyle(ChipKind.defaultTint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    labelPickerShown = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(ChipKind.defaultTint)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
            }
        } else {
            // 選択済み時：アイコン + チップ + 追加ボタンを表示
            Button {
                labelPickerShown = true
            } label: {
                HStack(alignment: .center, spacing: UIConstants.Spacing.extraLarge) {
                    Image(systemName: "tag")
                        .foregroundStyle(ChipKind.defaultTint)
                        .imageScale(.medium)
                        .frame(height: 28, alignment: .center)

                    FlowRow(spacing: 12, rowSpacing: 6) {
                        ForEach(Array(store.labelIds), id: \.self) { labelId in
                            if let label = labelOptions.first(where: { $0.id == labelId }) {
                                Chip(label.name, kind: .label, size: .small, showRemoveButton: true, colorDot: LabelColorId.from(label.colorId)?.color) {
                                    store.labelIds.remove(labelId)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // 追加ボタン（右端に固定）
                    Button {
                        labelPickerShown = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(ChipKind.defaultTint)
                            .imageScale(.large)
                    }
                    .buttonStyle(.plain)
                    .frame(height: 28, alignment: .center)
                }
                .padding(.vertical, UIConstants.Spacing.extraSmall)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var memberRow: some View {
        if store.memberIds.isEmpty {
            // 未選択時：選択ボタン + 追加ボタンを表示
            HStack(spacing: UIConstants.Spacing.medium) {
                Button { memberPickerShown = true } label: {
                    Label(L.VisitEdit.selectMember, systemImage: "person")
                        .foregroundStyle(ChipKind.defaultTint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    memberPickerShown = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(ChipKind.defaultTint)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
            }
        } else {
            // 選択済み時：アイコン + チップ + 追加ボタンを表示
            Button {
                memberPickerShown = true
            } label: {
                HStack(alignment: .center, spacing: UIConstants.Spacing.extraLarge) {
                    Image(systemName: "person")
                        .foregroundStyle(ChipKind.defaultTint)
                        .imageScale(.medium)
                        .frame(height: 28, alignment: .center)

                    FlowRow(spacing: 12, rowSpacing: 6) {
                        ForEach(Array(store.memberIds), id: \.self) { memberId in
                            if let name = memberOptions.first(where: { $0.id == memberId })?.name {
                                Chip(name, kind: .member, size: .small, showRemoveButton: true) {
                                    store.memberIds.remove(memberId)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // 追加ボタン（右端に固定）
                    Button {
                        memberPickerShown = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(ChipKind.defaultTint)
                            .imageScale(.large)
                    }
                    .buttonStyle(.plain)
                    .frame(height: 28, alignment: .center)
                }
                .padding(.vertical, UIConstants.Spacing.extraSmall)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Picker Sheet Contents

    @ViewBuilder
    private var labelPickerSheetContent: some View {
        LabelPickerSheet(
            selectedIds: $store.labelIds,
            labelOptions: $labelOptions,
            isPresented: $labelPickerShown,
            showCreateSheet: $labelCreateShown
        )
        .sheet(isPresented: $labelCreateShown) {
            LabelCreateSheet(
                newLabelName: $newLabelName,
                newLabelColorId: $newLabelColorId,
                isPresented: $labelCreateShown,
                onCreate: createLabelAndSelect
            )
        }
    }

    @ViewBuilder
    private var groupPickerSheetContent: some View {
        GroupPickerSheet(
            selectedId: $store.groupId,
            groupOptions: $groupOptions,
            isPresented: $groupPickerShown,
            showCreateSheet: $groupCreateShown
        )
        .sheet(isPresented: $groupCreateShown) {
            GroupCreateSheet(
                newGroupName: $newGroupName,
                isPresented: $groupCreateShown,
                onCreate: createGroupAndSelect
            )
        }
    }

    @ViewBuilder
    private var memberPickerSheetContent: some View {
        MemberPickerSheet(
            selectedIds: $store.memberIds,
            memberOptions: $memberOptions,
            isPresented: $memberPickerShown,
            showCreateSheet: $memberCreateShown
        )
        .sheet(isPresented: $memberCreateShown) {
            MemberCreateSheet(
                newMemberName: $newMemberName,
                isPresented: $memberCreateShown,
                onCreate: createMemberAndSelect
            )
        }
    }

    // MARK: - Create Actions

    private func createLabelAndSelect() {
        let name = newLabelName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let exist = labelOptions.first(where: { $0.name == name }) {
            store.labelIds.insert(exist.id)
        } else if let id = store.createLabel(name) {
            let tag = LabelTag(id: id, name: name, colorId: newLabelColorId)
            labelOptions.append(tag)
            store.labelIds.insert(id)
            // 色が設定されている場合は保存
            if let colorId = newLabelColorId {
                _ = try? AppContainer.shared.taxonomyRepo.updateLabelColor(id: id, colorId: colorId)
            }
        }
        newLabelName = ""
        newLabelColorId = nil
        labelCreateShown = false
    }

    private func createGroupAndSelect() {
        let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let exist = groupOptions.first(where: { $0.name == name }) {
            store.groupId = exist.id
        } else if let id = store.createGroup(name) {
            let tag = GroupTag(id: id, name: name)
            groupOptions.append(tag)
            store.groupId = id
        }
        newGroupName = ""
        groupCreateShown = false
    }

    private func createMemberAndSelect() {
        let name = newMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let exist = memberOptions.first(where: { $0.name == name }) {
            store.memberIds.insert(exist.id)
        } else if let id = store.createMember(name) {
            let tag = MemberTag(id: id, name: name)
            memberOptions.append(tag)
            store.memberIds.insert(id)
        }
        newMemberName = ""
        memberCreateShown = false
    }

    private var photoSection: some View {
        Section {
            ManualEntryPhotoGridView(
                store: store,
                showCamera: $showCamera,
                fullScreenIndex: $fullScreenIndex
            )
        } header: {
            Text(L.Photo.photo)
        }
    }

}

// MARK: - Photo Grid

private struct ManualEntryPhotoGridView: View {
    @Bindable var store: ManualEntryStore
    @Binding var showCamera: Bool
    @Binding var fullScreenIndex: Int?

    @State private var libSelection: [PhotosPickerItem] = []
    private let thumbSize: CGFloat = 64

    private var canAddMore: Bool {
        store.photoEffects.photoPathsEditing.count < AppConfig.maxPhotosPerVisit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            photoThumbnails
            if canAddMore {
                photoButtons
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var photoThumbnails: some View {
        if !store.photoEffects.photoPathsEditing.isEmpty {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: thumbSize), spacing: 5)], spacing: 5) {
                ForEach(Array(store.photoEffects.photoPathsEditing.enumerated()), id: \.offset) { idx, path in
                    PhotoThumb(
                        path: path,
                        size: thumbSize,
                        showDelete: true,
                        onTap: { fullScreenIndex = idx },
                        onDelete: { handlePhotoDelete(at: idx) }
                    )
                }
            }
            .padding(.top, 2)
        }
    }

    private func handlePhotoDelete(at idx: Int) {
        store.removePhoto(at: idx)
        if fullScreenIndex == idx {
            fullScreenIndex = nil
        } else if let currentIndex = fullScreenIndex, currentIndex > idx {
            fullScreenIndex = currentIndex - 1
        }
    }

    private var photoButtons: some View {
        HStack(spacing: 12) {
            PhotosPicker(
                selection: $libSelection,
                maxSelectionCount: AppConfig.maxPhotosPerVisit - store.photoEffects.photoPathsEditing.count,
                matching: .images
            ) {
                Label(L.Photo.photo, systemImage: "photo.on.rectangle")
            }
            .onChange(of: libSelection) { _, _ in
                Task { await loadSelectedItems() }
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

    @MainActor
    private func loadSelectedItems() async {
        guard !libSelection.isEmpty else { return }
        var images: [UIImage] = []
        images.reserveCapacity(libSelection.count)

        for item in libSelection {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }
        store.addPhotos(images)
        libSelection = []
    }
}

