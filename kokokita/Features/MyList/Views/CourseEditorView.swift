import SwiftUI
import MapKit
import PhotosUI

/// コース作成・編集画面
/// レイアウト: コース詳細画面に準拠（地図上半分 + スポットリスト下半分）
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
    @State private var showCourseSettings = false
    @State private var selectedSpotIndex: Int? = nil
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 36.5, longitude: 136.0),
            span: MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 10.0)
        )
    )

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // 地図エリア（上半分）
                mapArea
                    .frame(height: geo.size.height * 0.45)

                Divider()

                // スポットリストエリア（下半分）
                spotListArea
            }
        }
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
        // 新規スポット追加
        .sheet(isPresented: $showSpotEditorForNew) {
            SpotEditorSheet(mode: .create) { spot in viewModel.addSpot(spot) }
        }
        // 既存スポット編集
        .sheet(item: $showSpotEditorForEdit) { spot in
            if let idx = editingSpotIndex {
                SpotEditorSheet(mode: .edit(spot: spot)) { updated in
                    viewModel.updateSpot(updated, at: idx)
                }
            }
        }
        // コース設定シート
        .sheet(isPresented: $showCourseSettings) {
            CourseSettingsSheet(viewModel: viewModel)
        }
        .task { viewModel.loadIfNeeded() }
        .onChange(of: viewModel.didSave) { _, saved in if saved { dismiss() } }
        .onChange(of: viewModel.spots) { _, _ in fitMapToSpots() }
    }

    // MARK: - ナビゲーション

    private var navigationTitle: String {
        if !viewModel.title.isEmpty { return viewModel.title }
        switch viewModel.mode {
        case .create: return L.CourseEditor.createTitle
        case .edit:   return L.CourseEditor.editTitle
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
        ToolbarItem(placement: .principal) {
            // タイトルをインライン編集可能なTextField に
            TextField(L.CourseEditor.titlePlaceholder, text: $viewModel.title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 200)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            if viewModel.isSaving {
                ProgressView()
            } else {
                Button(L.Common.save) { Task { await viewModel.save() } }
                    .fontWeight(.semibold)
                    .disabled(viewModel.title.isEmpty)
            }
        }
    }

    // MARK: - 地図エリア

    private var mapArea: some View {
        Map(position: $cameraPosition) {
            ForEach(Array(viewModel.spots.enumerated()), id: \.element.id) { index, spot in
                if spot.hasValidCoordinate, let lat = spot.latitude, let lon = spot.longitude {
                    Annotation(
                        "",
                        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        anchor: .center
                    ) {
                        EditorSpotPinView(
                            orderNumber: index + 1,
                            isSelected: selectedSpotIndex == index
                        )
                        .onTapGesture { focusSpot(at: index) }
                    }
                }
            }
        }
        .mapStyle(.standard(emphasis: .muted))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .overlay(alignment: .topTrailing) {
            // コース設定ボタン
            Button {
                showCourseSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 36, height: 36)
                    .background(.regularMaterial, in: Circle())
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .padding(12)
        }
    }

    // MARK: - スポットリストエリア

    private var spotListArea: some View {
        VStack(spacing: 0) {
            // ヘッダー行（スポット数 + 追加ボタン）
            HStack {
                Text(L.CourseEditor.spotsSection)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showSpotEditorForNew = true
                } label: {
                    Label(L.CourseEditor.addSpot, systemImage: "plus")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.indigo)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGroupedBackground))

            Divider()

            if viewModel.spots.isEmpty {
                // 空状態
                VStack(spacing: 12) {
                    Image(systemName: "mappin.slash")
                        .font(.system(size: 36))
                        .foregroundStyle(.quaternary)
                    Text("スポットを追加してください")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                    Button {
                        showSpotEditorForNew = true
                    } label: {
                        Text(L.CourseEditor.addSpot)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.indigo)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // スポット一覧（EditMode で並び替え可能）
                List {
                    ForEach(Array(viewModel.spots.enumerated()), id: \.element.id) { index, spot in
                        spotRow(spot: spot, index: index)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingSpotIndex = index
                                showSpotEditorForEdit = spot
                                focusSpot(at: index)
                            }
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                            .listRowSeparator(.visible)
                    }
                    .onDelete { offsets in viewModel.deleteSpot(at: offsets) }
                    .onMove { from, to in viewModel.moveSpot(from: from, to: to) }
                }
                .listStyle(.plain)
                .environment(\.editMode, .constant(.active))
            }
        }
    }

    // MARK: - スポット行

    private func spotRow(spot: EditingSpot, index: Int) -> some View {
        HStack(spacing: 12) {
            // 番号バッジ
            ZStack {
                Circle()
                    .fill(spot.hasValidCoordinate
                          ? (selectedSpotIndex == index ? Color.indigo : Color.indigo.opacity(0.7))
                          : Color.secondary.opacity(0.35))
                    .frame(width: 28, height: 28)
                Text("\(index + 1)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            }

            // スポット情報
            VStack(alignment: .leading, spacing: 2) {
                Text(spot.name.isEmpty ? "（名称未設定）" : spot.name)
                    .font(.subheadline)
                    .foregroundStyle(spot.name.isEmpty ? .tertiary : .primary)

                if let addr = spot.address, !addr.isEmpty {
                    Text(addr)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if !spot.hasValidCoordinate {
                    Text(L.SpotEditor.noCoordinateWarning)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // スポット画像サムネイル
            if let img = spot.coverImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: - 地図フォーカス

    private func focusSpot(at index: Int) {
        let spots = viewModel.spots
        guard spots.indices.contains(index) else { return }
        let spot = spots[index]

        withAnimation(.easeInOut(duration: 0.3)) {
            if selectedSpotIndex == index {
                // 同じ行再タップ → 選択解除・全体表示
                selectedSpotIndex = nil
                fitMapToSpots()
            } else {
                selectedSpotIndex = index
                guard spot.hasValidCoordinate, let lat = spot.latitude, let lon = spot.longitude else { return }
                cameraPosition = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                ))
            }
        }
    }

    private func fitMapToSpots() {
        let validSpots = viewModel.spots.filter { $0.hasValidCoordinate }
        guard !validSpots.isEmpty else {
            cameraPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 36.5, longitude: 136.0),
                span: MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 10.0)
            ))
            return
        }

        let coords = validSpots.compactMap { spot -> CLLocationCoordinate2D? in
            guard let lat = spot.latitude, let lon = spot.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }

        if coords.count == 1 {
            cameraPosition = .region(MKCoordinateRegion(
                center: coords[0],
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            ))
            return
        }

        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLon = lons.min()!, maxLon = lons.max()!
        cameraPosition = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 1.5, 0.01),
                                   longitudeDelta: max((maxLon - minLon) * 1.5, 0.01))
        ))
    }
}

// MARK: - エディタ用スポットピン

private struct EditorSpotPinView: View {
    let orderNumber: Int
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.indigo : Color.indigo.opacity(0.75))
                .frame(width: 28, height: 28)
                .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
            Text("\(orderNumber)")
                .font(.caption.bold())
                .foregroundStyle(.white)
        }
        .scaleEffect(isSelected ? 1.2 : 1.0)
        .animation(.spring(response: 0.25), value: isSelected)
    }
}

// MARK: - コース設定シート

/// カバー画像・説明・半径・後付け設定をまとめたシート
private struct CourseSettingsSheet: View {
    @Bindable var viewModel: CourseEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var coverImagePickerItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Form {
                // カバー画像
                Section {
                    HStack {
                        Text(L.CourseEditor.coverImage)
                        Spacer()
                        if let img = viewModel.coverImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 52, height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        PhotosPicker(selection: $coverImagePickerItem, matching: .images) {
                            Text(viewModel.coverImage == nil ? L.Common.edit : "変更")
                                .foregroundStyle(.indigo)
                        }
                    }
                }

                // コース説明
                Section(L.CourseEditor.summaryPlaceholder) {
                    TextField(L.CourseEditor.summaryPlaceholder, text: $viewModel.summary, axis: .vertical)
                        .lineLimit(3...6)
                }

                // 達成判定半径
                Section {
                    VStack(spacing: 8) {
                        HStack {
                            Text(L.CourseEditor.recognitionRadius)
                            Spacer()
                            Text(L.CourseEditor.recognitionRadiusValue(Int(viewModel.recognitionRadiusMeters)))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $viewModel.recognitionRadiusMeters, in: 50...1000, step: 10)
                            .tint(.indigo)
                    }
                    .padding(.vertical, 4)
                }

                // 後付け記録
                Section {
                    Toggle(L.CourseEditor.allowRetroactive, isOn: $viewModel.allowRetroactive)
                        .tint(.indigo)
                }
            }
            .navigationTitle(L.CourseEditor.settingsSection)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L.Common.done) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onChange(of: coverImagePickerItem) { _, item in
                loadCoverImage(from: item)
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func loadCoverImage(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                viewModel.coverImage = img
                viewModel.localCoverImagePath = nil
            }
        }
    }
}
