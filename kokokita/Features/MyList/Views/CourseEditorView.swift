import SwiftUI
import MapKit
import PhotosUI

/// コース作成・編集画面
struct CourseEditorView: View {

    // MARK: - 初期化

    enum Mode {
        case create
        case edit(courseId: UUID)
    }

    private let mode: Mode
    @State private var viewModel: CourseEditorViewModel

    init(mode: Mode) {
        self.mode = mode
        let vmMode: CourseEditorViewModel.Mode
        switch mode {
        case .create: vmMode = .create
        case .edit(let id): vmMode = .edit(courseId: id)
        }
        _viewModel = State(initialValue: CourseEditorViewModel(mode: vmMode))
    }

    // MARK: - UI 状態

    @Environment(\.dismiss) private var dismiss
    @State private var showUnsavedAlert = false
    @State private var showSpotEditorForNew = false
    @State private var showSpotEditorForEdit: EditingSpot?
    @State private var editingSpotIndex: Int?
    @State private var isSettingsSectionExpanded = true
    @State private var coverImagePickerItem: PhotosPickerItem?
    @State private var mapRegion = MapCameraPosition.automatic

    var body: some View {
        contentView
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar { toolbarContent }
            .alert(L.CourseEditor.unsavedChangesTitle, isPresented: $showUnsavedAlert) {
                Button(L.CourseEditor.discard, role: .destructive) { dismiss() }
                Button(L.Common.cancel, role: .cancel) {}
            } message: {
                Text(L.CourseEditor.unsavedChangesMessage)
            }
            .sheet(isPresented: $showSpotEditorForNew) {
                SpotEditorSheet(mode: .create) { spot in viewModel.addSpot(spot) }
            }
            .sheet(item: $showSpotEditorForEdit) { spot in
                if let idx = editingSpotIndex {
                    SpotEditorSheet(mode: .edit(spot: spot)) { updated in
                        viewModel.updateSpot(updated, at: idx)
                    }
                }
            }
            .task { viewModel.loadIfNeeded() }
            .onChange(of: viewModel.didSave) { _, saved in if saved { dismiss() } }
            .onChange(of: coverImagePickerItem) { _, item in loadCoverImage(from: item) }
            .onChange(of: viewModel.spots) { _, _ in updateMapRegion() }
    }

    // MARK: - コンテンツビュー（型推論分割）

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 0) {
                mapSection.frame(height: 220)
                courseSettingsSection
                spotListSection
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                if viewModel.hasChanges { showUnsavedAlert = true } else { dismiss() }
            } label: {
                Image(systemName: "chevron.left").fontWeight(.semibold)
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            if viewModel.isSaving {
                ProgressView()
            } else {
                Button(L.Common.save) { Task { await saveAndDismiss() } }
                    .fontWeight(.semibold)
                    .disabled(viewModel.title.isEmpty)
            }
        }
    }

    // MARK: - ナビゲーションタイトル

    private var navigationTitle: String {
        switch mode {
        case .create: return L.CourseEditor.createTitle
        case .edit: return L.CourseEditor.editTitle
        }
    }

    // MARK: - 地図セクション

    private var mapSection: some View {
        Map(position: $mapRegion) {
            ForEach(Array(viewModel.spots.enumerated()), id: \.element.id) { index, spot in
                if spot.hasValidCoordinate, let lat = spot.latitude, let lon = spot.longitude {
                    Annotation("", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)) {
                        ZStack {
                            Circle()
                                .fill(Color.indigo)
                                .frame(width: 28, height: 28)
                            Text("\(index + 1)")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
        .mapStyle(.standard)
        .disabled(true)
    }

    // MARK: - コース設定セクション

    private var courseSettingsSection: some View {
        VStack(spacing: 0) {
            // セクションヘッダー（折りたたみ）
            Button {
                withAnimation(.snappy) {
                    isSettingsSectionExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(L.CourseEditor.settingsSection)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: isSettingsSectionExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if isSettingsSectionExpanded {
                VStack(spacing: 16) {
                    // タイトル入力
                    TextField(L.CourseEditor.titlePlaceholder, text: $viewModel.title)
                        .font(.title3.weight(.semibold))
                        .padding(.horizontal, 16)

                    Divider().padding(.horizontal, 16)

                    // 説明文
                    TextField(L.CourseEditor.summaryPlaceholder, text: $viewModel.summary, axis: .vertical)
                        .lineLimit(3...6)
                        .padding(.horizontal, 16)

                    Divider().padding(.horizontal, 16)

                    // カバー画像
                    coverImageRow

                    Divider().padding(.horizontal, 16)

                    // 達成判定半径
                    radiusRow

                    Divider().padding(.horizontal, 16)

                    // 後付け記録トグル
                    Toggle(L.CourseEditor.allowRetroactive, isOn: $viewModel.allowRetroactive)
                        .padding(.horizontal, 16)
                        .tint(.indigo)
                }
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Divider()
        }
    }

    // MARK: - カバー画像行

    private var coverImageRow: some View {
        HStack {
            Text(L.CourseEditor.coverImage)
                .foregroundStyle(.primary)
            Spacer()
            if let img = viewModel.coverImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            PhotosPicker(selection: $coverImagePickerItem, matching: .images) {
                Text(viewModel.coverImage == nil ? L.Common.edit : "変更")
                    .font(.subheadline)
                    .foregroundStyle(.indigo)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - 半径行

    private var radiusRow: some View {
        VStack(spacing: 8) {
            HStack {
                Text(L.CourseEditor.recognitionRadius)
                    .foregroundStyle(.primary)
                Spacer()
                Text(L.CourseEditor.recognitionRadiusValue(Int(viewModel.recognitionRadiusMeters)))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $viewModel.recognitionRadiusMeters, in: 50...1000, step: 10)
                .tint(.indigo)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - スポット一覧

    private var spotListSection: some View {
        VStack(spacing: 0) {
            // セクションヘッダー
            HStack {
                Text(L.CourseEditor.spotsSection)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // スポット行（EditMode 相当の並び替え）
            ForEach(Array(viewModel.spots.enumerated()), id: \.element.id) { index, spot in
                spotRow(spot: spot, index: index)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingSpotIndex = index
                        showSpotEditorForEdit = spot
                    }
            }
            .onDelete { offsets in viewModel.deleteSpot(at: offsets) }
            .onMove { from, to in viewModel.moveSpot(from: from, to: to) }

            // スポット追加ボタン
            Button {
                showSpotEditorForNew = true
            } label: {
                Text(L.CourseEditor.addSpot)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.indigo)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
        }
        .environment(\.editMode, .constant(.active))
    }

    // MARK: - スポット行

    private func spotRow(spot: EditingSpot, index: Int) -> some View {
        HStack(spacing: 12) {
            // 番号バッジ
            ZStack {
                Circle()
                    .fill(spot.hasValidCoordinate ? Color.indigo : Color.secondary.opacity(0.4))
                    .frame(width: 28, height: 28)
                Text("\(index + 1)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            }

            // スポット情報
            VStack(alignment: .leading, spacing: 2) {
                Text(spot.name.isEmpty ? "（名称未設定）" : spot.name)
                    .font(.subheadline)
                    .foregroundStyle(spot.name.isEmpty ? .secondary : .primary)
                if let desc = spot.spotDescription, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if !spot.hasValidCoordinate {
                    Text(L.SpotEditor.noCoordinateWarning)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: - ヘルパー

    private func saveAndDismiss() async {
        await viewModel.save()
    }

    private func loadCoverImage(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                viewModel.coverImage = img
                // パスをリセットして再保存させる
                viewModel.localCoverImagePath = nil
            }
        }
    }

    private func updateMapRegion() {
        let validSpots = viewModel.spots.filter { $0.hasValidCoordinate }
        guard !validSpots.isEmpty else {
            mapRegion = .automatic
            return
        }
        let coords = validSpots.compactMap { spot -> CLLocationCoordinate2D? in
            guard let lat = spot.latitude, let lon = spot.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        guard !coords.isEmpty else { return }
        let avgLat = coords.map(\.latitude).reduce(0, +) / Double(coords.count)
        let avgLon = coords.map(\.longitude).reduce(0, +) / Double(coords.count)
        mapRegion = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
    }
}
