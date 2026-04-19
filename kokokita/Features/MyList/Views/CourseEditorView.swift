import SwiftUI
import MapKit
import PhotosUI

/// コース作成・編集画面
/// 閲覧モード（isEditing = false）と編集モード（isEditing = true）を一画面で切り替える
struct CourseEditorView: View {

    // MARK: - 初期化

    enum Mode {
        case create
        case edit(courseId: UUID)
    }

    private let mode: Mode
    @State private var viewModel: CourseEditorViewModel
    /// 新規作成は常に編集モードから開始
    @State private var isEditing: Bool

    init(mode: Mode) {
        self.mode = mode
        let vmMode: CourseEditorViewModel.Mode
        switch mode {
        case .create:        vmMode = .create
        case .edit(let id):  vmMode = .edit(courseId: id)
        }
        _viewModel = State(initialValue: CourseEditorViewModel(mode: vmMode))
        switch mode {
        case .create: _isEditing = State(initialValue: true)
        case .edit:   _isEditing = State(initialValue: false)
        }
    }

    // MARK: - UI 状態

    @Environment(\.dismiss) private var dismiss
    @State private var showDiscardAlert = false    // 作成キャンセル確認
    @State private var showCancelAlert = false     // 編集キャンセル確認
    @State private var showSpotEditorForNew = false
    @State private var showSpotEditorForEdit: EditingSpot?
    @State private var editingSpotIndex: Int?
    @State private var showCourseSettings = false
    @State private var selectedSpotIndex: Int? = nil
    @State private var selectedSpotScreenPoint: CGPoint? = nil
    /// List の editMode を明示的に State で管理（onChange 内の withAnimation でも確実に反映するため）
    @State private var listEditMode: EditMode = .inactive
    /// タイトル入力欄のフォーカス管理
    @FocusState private var titleFocused: Bool
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
                mapArea
                    .frame(height: geo.size.height * 0.45)
                Divider()
                spotListArea
            }
        }
        .navigationTitle(isEditing ? "" : viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(shouldHideBackButton)
        .toolbar { toolbarContent }
        // 作成キャンセル確認（dismiss）
        .alert(L.CourseEditor.unsavedChangesTitle, isPresented: $showDiscardAlert) {
            Button(L.CourseEditor.discard, role: .destructive) { dismiss() }
            Button(L.Common.cancel, role: .cancel) {}
        } message: {
            Text(L.CourseEditor.unsavedChangesMessage)
        }
        // 編集キャンセル確認（変更を破棄して閲覧モードに戻る）
        .alert(L.CourseEditor.unsavedChangesTitle, isPresented: $showCancelAlert) {
            Button(L.CourseEditor.discard, role: .destructive) { cancelEditing() }
            Button(L.Common.cancel, role: .cancel) {}
        } message: {
            Text(L.CourseEditor.cancelChangesMessage)
        }
        // 新規スポット追加シート
        .sheet(isPresented: $showSpotEditorForNew) {
            SpotEditorSheet(mode: .create) { spot in viewModel.addSpot(spot) }
        }
        // 既存スポット編集シート
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
        .task {
            viewModel.loadIfNeeded()
            // 新規作成時はタイトル欄を自動フォーカスしてキャレットを表示
            if case .create = mode {
                try? await Task.sleep(nanoseconds: 400_000_000)
                titleFocused = true
            }
        }
        .onChange(of: isEditing) { _, editing in
            // 編集モード開始時にタイトルフォーカス
            if editing { titleFocused = true }
        }
        .onChange(of: viewModel.didSave) { _, saved in
            guard saved else { return }
            switch viewModel.mode {
            case .create:
                // 作成完了 → dismissせず閲覧モードへ遷移
                // ViewModel を .edit モードに切り替え、originalCourse をセット
                viewModel.resetAfterCreateSave()
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                        listEditMode = .inactive
                        isEditing = false
                        selectedSpotIndex = nil
                    }
                    fitMapToSpots()
                }
            case .edit:
                // 編集完了 → 閲覧モードに戻る
                // async完了後のonChangeではアニメーションコンテキストが切れるため
                // 次RunLoopで実行してキャンセル時と同じヌルッとした動きにする
                viewModel.resetAfterSave()
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                        listEditMode = .inactive
                        isEditing = false
                        selectedSpotIndex = nil
                    }
                    fitMapToSpots()
                }
            }
        }
        .onChange(of: viewModel.spots) { _, _ in
            if isEditing { fitMapToSpots() }
        }
    }

    // MARK: - バック制御

    /// システムバックボタンを隠すか（編集中 or 作成モードは常に隠す）
    private var shouldHideBackButton: Bool {
        if isEditing { return true }
        if case .create = viewModel.mode { return true }
        return false
    }

    // MARK: - ツールバー

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Leading: 編集中のみカスタムボタン
        if shouldHideBackButton {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { handleLeadingButton() } label: {
                    switch viewModel.mode {
                    case .create:
                        // 作成モードは戻るシェブロン
                        Image(systemName: "chevron.left").fontWeight(.semibold)
                    case .edit:
                        // 編集モードも戻るシェブロン
                        Image(systemName: "chevron.left").fontWeight(.semibold)
                    }
                }
            }
        }

        // Principal: 編集中のみタイトル TextField
        if isEditing {
            ToolbarItem(placement: .principal) {
                // ZStack で固定幅を確保し、プレースホルダーとカーソル表示を両立させる
                // - 固定幅: 空テキスト時も下線・タップ領域が崩れない
                // - カスタムプレースホルダー: 未フォーカス時のみ表示してカーソルを隠さない
                ZStack {
                    TextField("", text: $viewModel.title)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .focused($titleFocused)
                    if viewModel.title.isEmpty && !titleFocused {
                        Text(L.CourseEditor.titlePlaceholder)
                            .font(.headline)
                            .foregroundStyle(Color(.placeholderText))
                            .lineLimit(1)
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: 180)
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
                .background(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.25))
                        .frame(height: 1)
                }
                .contentShape(Rectangle())
                .onTapGesture { titleFocused = true }
            }
        }

        // Trailing: 閲覧中→「編集」 / 編集中→「保存」
        ToolbarItem(placement: .navigationBarTrailing) {
            if isEditing {
                if viewModel.isSaving {
                    ProgressView()
                } else {
                    Button(L.Common.save) {
                        Task { await viewModel.save() }
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.title.isEmpty)
                }
            } else {
                Button(L.Common.edit) {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
                        isEditing = true
                        listEditMode = .active
                    }
                }
            }
        }
    }

    private func handleLeadingButton() {
        switch viewModel.mode {
        case .create:
            if viewModel.hasChanges { showDiscardAlert = true } else { dismiss() }
        case .edit:
            if viewModel.hasChanges { showCancelAlert = true } else { cancelEditing() }
        }
    }

    private func cancelEditing() {
        viewModel.reloadOriginalData()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) {
            listEditMode = .inactive
            isEditing = false
            selectedSpotIndex = nil
        }
        fitMapToSpots()
    }

    // MARK: - 地図エリア

    private var mapArea: some View {
        MapReader { proxy in
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
            .onChange(of: selectedSpotIndex) { _, _ in
                selectedSpotScreenPoint = nil
            }
            .onChange(of: isEditing) { _, editing in
                if editing {
                    selectedSpotScreenPoint = nil
                } else {
                    updateSpotScreenPoint(proxy: proxy)
                }
            }
            .onMapCameraChange(frequency: .onEnd) { _ in
                withAnimation(.easeInOut(duration: 0.2)) {
                    updateSpotScreenPoint(proxy: proxy)
                }
            }
            .onMapCameraChange(frequency: .continuous) { _ in
                guard selectedSpotScreenPoint != nil else { return }
                updateSpotScreenPoint(proxy: proxy)
            }
            .overlay {
                editorLeaderLineOverlay
            }
            .overlay(alignment: .topTrailing) {
                // コース設定ボタン: 編集中のみ表示
                if isEditing {
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
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.85), value: isEditing)
        }
    }

    // MARK: - スポットリストエリア

    private var spotListArea: some View {
        VStack(spacing: 0) {
            // ヘッダー行
            HStack {
                Text(L.CourseEditor.spotsSection)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                // 追加ボタン: 編集中のみ表示（ニョキ）
                if isEditing {
                    Button {
                        showSpotEditorForNew = true
                    } label: {
                        Text(L.CourseEditor.addSpot)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.indigo)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGroupedBackground))
            .animation(.spring(response: 0.38, dampingFraction: 0.85), value: isEditing)

            Divider()

            if viewModel.spots.isEmpty {
                emptySpotState
            } else {
                spotList
            }
        }
    }

    private var emptySpotState: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 36))
                .foregroundStyle(.quaternary)
            Text(L.CourseEditor.noSpotsMessage)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            if isEditing {
                Button {
                    showSpotEditorForNew = true
                } label: {
                    Text(L.CourseEditor.addSpot)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.indigo)
                }
                .transition(.scale(scale: 0.7).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.38, dampingFraction: 0.85), value: isEditing)
    }

    private var spotList: some View {
        List {
            ForEach(Array(viewModel.spots.enumerated()), id: \.element.id) { index, spot in
                spotRow(spot: spot, index: index, isSelected: selectedSpotIndex == index)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isEditing {
                            editingSpotIndex = index
                            showSpotEditorForEdit = spot
                        }
                        focusSpot(at: index)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.visible)
            }
            // .onDelete は使わない（スワイプ削除を完全に無効化するため）
            // 削除はrowに埋め込んだカスタムボタンのみで行う
            .onMove { from, to in viewModel.moveSpot(from: from, to: to) }
        }
        .listStyle(.plain)
        .environment(\.editMode, $listEditMode)
        .animation(.spring(response: 0.38, dampingFraction: 0.85), value: isEditing)
    }

    // MARK: - スポット行

    private func spotRow(spot: EditingSpot, index: Int, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            // 編集モード時のみ削除ボタンを表示（.onDelete を使わず完全にスワイプ削除を無効化）
            if isEditing {
                Button {
                    withAnimation {
                        viewModel.deleteSpot(at: IndexSet(integer: index))
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }

            // 番号バッジ（コース詳細の未達成スポットと同じデザイン）
            ZStack {
                Circle()
                    .fill(spot.hasValidCoordinate
                          ? Color(uiColor: .systemGray4)
                          : Color(uiColor: .systemGray5))
                    .frame(width: 32, height: 32)
                Text("\(index + 1)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            }

            // スポット情報
            VStack(alignment: .leading, spacing: 2) {
                Text(spot.name.isEmpty ? L.CourseEditor.unnamedSpot : spot.name)
                    .font(.subheadline)
                    .foregroundStyle(spot.name.isEmpty ? .tertiary : .primary)

                if let description = spot.spotDescription,
                   !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

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
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 10)
        .background {
            EditorSpotRowBackdropView(spot: spot, isSelected: isSelected)
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.85), value: isEditing)
    }

    // MARK: - 地図フォーカス

    private func focusSpot(at index: Int) {
        let spots = viewModel.spots
        guard spots.indices.contains(index) else { return }
        let spot = spots[index]

        withAnimation(.easeInOut(duration: 0.3)) {
            if selectedSpotIndex == index {
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

    private func updateSpotScreenPoint(proxy: MapProxy) {
        guard !isEditing,
              let index = selectedSpotIndex,
              viewModel.spots.indices.contains(index) else {
            selectedSpotScreenPoint = nil
            return
        }

        let spot = viewModel.spots[index]
        guard spot.hasValidCoordinate,
              let lat = spot.latitude,
              let lon = spot.longitude else {
            selectedSpotScreenPoint = nil
            return
        }

        selectedSpotScreenPoint = proxy.convert(
            CLLocationCoordinate2D(latitude: lat, longitude: lon),
            to: .local
        )
    }

    @ViewBuilder
    private var editorLeaderLineOverlay: some View {
        if !isEditing,
           let spotPoint = selectedSpotScreenPoint,
           let index = selectedSpotIndex,
           viewModel.spots.indices.contains(index) {
            let spot = viewModel.spots[index]
            let localImage = spot.coverImage ?? spot.localCoverImagePath.flatMap { LocalImageStorage.shared.load(from: $0) }
            let remoteURL = spot.coverImageUrl.flatMap(URL.init(string:))

            if localImage != nil || remoteURL != nil {
                EditorSpotLeaderLineView(
                    spotPoint: spotPoint,
                    localImage: localImage,
                    imageUrl: remoteURL
                )
                .transition(.opacity)
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
            span: MKCoordinateSpan(
                latitudeDelta: max((maxLat - minLat) * 1.5, 0.01),
                longitudeDelta: max((maxLon - minLon) * 1.5, 0.01)
            )
        ))
    }
}

private struct EditorSpotLeaderLineView: View {
    let spotPoint: CGPoint
    var localImage: UIImage? = nil
    var imageUrl: URL? = nil

    private let imageWidth: CGFloat = 132
    private let imageHeight: CGFloat = 88
    private let margin: CGFloat = 12

    var body: some View {
        GeometryReader { geo in
            let imageCenter = CGPoint(
                x: geo.size.width - imageWidth / 2 - margin,
                y: imageHeight / 2 + margin
            )
            let lineEnd = CGPoint(
                x: imageCenter.x - imageWidth / 2,
                y: imageCenter.y + imageHeight / 2
            )

            ZStack {
                Canvas { ctx, _ in
                    let path: Path = {
                        var path = Path()
                        path.move(to: spotPoint)
                        path.addLine(to: lineEnd)
                        return path
                    }()

                    ctx.stroke(
                        path,
                        with: .color(.black.opacity(0.25)),
                        style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                    )
                    ctx.stroke(
                        path,
                        with: .color(.white.opacity(0.95)),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: spotPoint.x - 4.5, y: spotPoint.y - 4.5, width: 9, height: 9)),
                        with: .color(.black.opacity(0.25))
                    )
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: spotPoint.x - 3.5, y: spotPoint.y - 3.5, width: 7, height: 7)),
                        with: .color(.white.opacity(0.95))
                    )
                }
                .allowsHitTesting(false)

                Group {
                    if let localImage {
                        Image(uiImage: localImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: imageWidth, height: imageHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 2)
                    } else if let imageUrl {
                        AsyncImage(url: imageUrl) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: imageWidth, height: imageHeight)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 2)
                            case .empty:
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(.regularMaterial)
                                    .frame(width: imageWidth, height: imageHeight)
                                    .overlay(ProgressView().controlSize(.small))
                                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
                            case .failure:
                                EmptyView()
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                }
                .position(imageCenter)
            }
            .clipped()
        }
    }
}

private struct EditorSpotRowBackdropView: View {
    let spot: EditingSpot
    let isSelected: Bool

    private var hasImage: Bool {
        spot.coverImage != nil || spot.localCoverImagePath != nil || spot.coverImageUrl != nil
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .trailing) {
                if hasImage {
                    EditorSpotRowBackdropImageView(spot: spot)
                        .frame(
                            width: max(geo.size.width * (isSelected ? 0.6 : 0.55), 188),
                            height: geo.size.height
                        )
                        .clipped()
                        .opacity(isSelected ? 0.56 : 0.44)
                        .saturation(isSelected ? 1.08 : 1.03)
                        .contrast(1.1)
                        .offset(x: 10)
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .white.opacity(0.22), location: 0.14),
                                    .init(color: .white.opacity(0.58), location: 0.4),
                                    .init(color: .white, location: 0.78)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    LinearGradient(
                        colors: [
                            Color(uiColor: .systemBackground),
                            Color(uiColor: .systemBackground).opacity(0.68),
                            Color(uiColor: .systemBackground).opacity(0.14)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }

                if isSelected {
                    Color.indigo.opacity(0.07)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .allowsHitTesting(false)
    }
}

private struct EditorSpotRowBackdropImageView: View {
    let spot: EditingSpot

    var body: some View {
        Group {
            if let image = spot.coverImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let path = spot.localCoverImagePath,
                      let image = LocalImageStorage.shared.load(from: path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let urlString = spot.coverImageUrl,
                      let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Color.clear
                    }
                }
            } else {
                Color.clear
            }
        }
    }
}

// MARK: - エディタ用スポットピン

private struct EditorSpotPinView: View {
    let orderNumber: Int
    let isSelected: Bool

    private var size: CGFloat { isSelected ? 18 : 14 }

    var body: some View {
        ZStack {
            // 白縁 + 影（選択時は indigo 縁）
            Circle()
                .fill(isSelected ? Color.indigo : .white)
                .frame(width: size + 5, height: size + 5)
                .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
            // ピン本体（未達成と同じ systemGray3）
            Circle()
                .fill(Color(uiColor: .systemGray3))
                .frame(width: size, height: size)
            Text("\(orderNumber)")
                .font(.system(size: isSelected ? 8 : 6, weight: .bold))
                .foregroundStyle(.white)
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - コース設定シート

/// カバー画像・説明・半径・後付け設定をまとめたシート
private struct CourseSettingsSheet: View {
    @Bindable var viewModel: CourseEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var coverImagePickerItem: PhotosPickerItem?
    /// カバー画像はローカル State で管理し、ViewModel の再描画によるチラつきを防ぐ
    @State private var localCoverImage: UIImage?
    @State private var didClearImage = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {

                    // カバー画像
                    VStack(spacing: 10) {
                        HStack {
                            Spacer()
                            ZStack(alignment: .bottomTrailing) {
                                PhotosPicker(selection: $coverImagePickerItem, matching: .images) {
                                    ZStack {
                                        if let img = localCoverImage {
                                            Image(uiImage: img)
                                                .resizable()
                                                .scaledToFill()
                                        } else {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color(.systemGray5))
                                            Image(systemName: "photo")
                                                .font(.system(size: 26))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(width: 96, height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(Color(.systemGray4), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                // 画像なし: 鉛筆バッジ（タップで選択を促す）
                                // 画像あり: ばつボタン（タップで削除）
                                if localCoverImage == nil {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.white, Color.indigo)
                                        .offset(x: 5, y: 5)
                                        .allowsHitTesting(false)
                                } else {
                                    Button {
                                        localCoverImage = nil
                                        didClearImage = true
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(.white, Color(.systemGray2))
                                            .offset(x: 5, y: 5)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                    Divider().padding(.horizontal, 20)

                    // コース説明
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L.CourseEditor.summaryPlaceholder)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 16)
                        TextField(L.CourseEditor.summaryPlaceholder, text: $viewModel.summary, axis: .vertical)
                            .font(.body)
                            .lineLimit(3...6)
                            .padding(.bottom, 12)
                    }
                    .padding(.horizontal, 20)

                    Divider().padding(.horizontal, 20)

                    // 達成判定半径
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(L.CourseEditor.recognitionRadius)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(L.CourseEditor.recognitionRadiusValue(Int(viewModel.recognitionRadiusMeters)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .padding(.top, 14)
                        Slider(value: $viewModel.recognitionRadiusMeters, in: 50...1000, step: 10)
                            .tint(.indigo)
                            .padding(.bottom, 14)
                    }
                    .padding(.horizontal, 20)

                    Divider().padding(.horizontal, 20)

                    // 後付け記録
                    Toggle(L.CourseEditor.allowRetroactive, isOn: $viewModel.allowRetroactive)
                        .tint(.indigo)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)

                    Divider().padding(.horizontal, 20)
                }
            }
            .navigationTitle(L.CourseEditor.settingsSection)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L.Common.done) {
                        // シートを閉じる前にローカル状態を ViewModel に反映
                        if didClearImage && localCoverImage == nil {
                            viewModel.coverImage = nil
                            viewModel.localCoverImagePath = nil
                        } else if let img = localCoverImage {
                            viewModel.coverImage = img
                            viewModel.localCoverImagePath = nil
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                // シート表示時に ViewModel の現在値をローカルに読み込む
                localCoverImage = viewModel.coverImage
            }
            .onChange(of: coverImagePickerItem) { _, item in
                loadCoverImage(from: item)
            }
        }
        .presentationDetents([.large])
    }

    private func loadCoverImage(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                // ローカル State のみ更新 → ViewModel は「完了」ボタン時に反映
                localCoverImage = img
                didClearImage = false
            }
        }
    }
}
